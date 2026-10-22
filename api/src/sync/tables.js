const Joi = require('joi');

const {
  visit_entry_checks: { vitals: VISIT_ENTRY_CHECKS, blood_sugar_conversion: { mg_dl_per_mmol_l: MG_DL_PER_MMOL_L } },
  gestational_age: GESTATION,
} = require('../../../clinical-rules/clinical-rules.json');

// Tables that devices may push and pull through /sync, with the fields the
// device sends (camelCase) and the column each maps to. Only tables listed here
// can be synced, and their names are the only identifiers ever placed in SQL.
// Add a table here when its module is built, together with its tests.
//
// `duplicateOf` marks a table whose new records are checked for a likely
// duplicate (M3 FE-2): it names the columns that must match. A possible
// duplicate is stored and listed on the supervisor's Conflict Review page.
//
// `parent` names the record a row belongs to (a woman's household, a
// pregnancy's woman). The parent must already be on the server and in the same
// area, so the device pushes parents first. Pull order can still bring a child
// before its parent (an edited parent gets a higher server_seq), so devices
// must not require the parent when they apply a pulled row.
//
// Every listed table has the sync base columns (id, server_seq, version, area_id,
// created_by, created_on_device, synced_at, deleted_at); see docs/schema-v1.md.

const text = (max) => Joi.string().trim().max(max).empty('').allow(null).default(null);
const coordinate = (limit) => Joi.number().min(-limit).max(limit).precision(6).allow(null).default(null);
const reference = () => Joi.string().guid({ version: 'uuidv4' }).required();
const count = () => Joi.number().integer().min(0).max(30).default(0);
const flag = () => Joi.boolean().default(false);

// A danger-sign checklist answer (M3 FE-1, M4 FE-4): yes or no; null means the
// question was not asked (visits recorded before the checklist existed).
const answer = () => Joi.boolean().allow(null).default(null);

// A vital sign in its stored unit. Its bounds are the "allowed" range in the
// Clinical Rules Table (clinical-rules/, P0-11), the same table the app reads, so
// a visit saved offline is never refused at sync. They only refuse impossible
// values; implausible ones (for example systolic BP outside 60-250) are
// confirmed in the app.
const vital = (field, decimals = 0) => {
  const [min, max] = VISIT_ENTRY_CHECKS[field].allowed;
  return (decimals ? Joi.number().precision(decimals) : Joi.number().integer()).min(min).max(max).allow(null).default(null);
};

// A calendar date as YYYY-MM-DD (DATE columns are read back as the same text, see db/pool.js).
const calendarDate = () =>
  Joi.string()
    .pattern(/^\d{4}-\d{2}-\d{2}$/)
    .custom((value, helpers) => {
      const date = new Date(`${value}T00:00:00Z`);
      return !Number.isNaN(date.getTime()) && date.toISOString().startsWith(value) ? value : helpers.error('any.invalid');
    });

const DAY_MS = 24 * 60 * 60 * 1000;
const dayNumber = (date) => Date.parse(`${date}T00:00:00Z`) / DAY_MS;

// Gestational age in weeks on a date, from the estimated delivery date (M2 FE-1).
function weeksOn(edd, date) {
  return GESTATION.full_term_weeks - (dayNumber(edd) - dayNumber(date)) / 7;
}

// The estimated delivery date from the pregnancy month only: the month's
// midpoint, as the Clinical Rules Table describes (gestational_age).
function eddFromMonth(registeredOn, month) {
  const weeks = (month - 0.5) * GESTATION.weeks_per_month;
  const days = Math.round((GESTATION.full_term_weeks - weeks) * 7);
  return new Date((dayNumber(registeredOn) + days) * DAY_MS).toISOString().slice(0, 10);
}

const TABLES = {
  // M2 FE-3: household with GPS. The first table synced end to end (P0-6).
  households: {
    fields: {
      householdNumber: { column: 'household_number', schema: text(50) },
      address: { column: 'address', schema: text(500) },
      village: { column: 'village', schema: text(200) },
      latitude: { column: 'latitude', type: 'number', schema: coordinate(90) },
      longitude: { column: 'longitude', type: 'number', schema: coordinate(180) },
    },
    check(data) {
      return (data.latitude === null) === (data.longitude === null)
        ? null
        : 'latitude and longitude must be given together';
    },
  },

  // M2 FE-1: registered woman. The patient ID is [LHW code]-[activation
  // number]-[sequence] made on the phone, so it is unique without a connection.
  // The same name and husband's name in the same household is a possible
  // duplicate (M3 FE-2).
  women: {
    parent: { field: 'householdId', table: 'households' },
    duplicateOf: { sameColumns: ['household_id'], sameText: ['name', 'husband_name'] },
    fields: {
      householdId: { column: 'household_id', schema: reference() },
      patientCode: {
        column: 'patient_code',
        schema: Joi.string().trim().max(40).pattern(/^[A-Za-z0-9-]+$/).required(),
      },
      name: { column: 'name', schema: Joi.string().trim().min(1).max(200).required() },
      age: { column: 'age', type: 'number', schema: Joi.number().integer().min(10).max(60).allow(null).default(null) },
      husbandName: { column: 'husband_name', schema: text(200) },
      contactNumber: { column: 'contact_number', schema: text(20).pattern(/^[0-9+\- ]+$/) },
    },
  },

  // M2 FE-1: the pregnancy file. A woman can have several pregnancies over
  // time, but only one active at a time (a unique index in the database).
  pregnancies: {
    parent: { field: 'womanId', table: 'women' },
    fields: {
      womanId: { column: 'woman_id', schema: reference() },
      registeredOn: { column: 'registered_on', schema: calendarDate().required() },
      pregnancyMonthAtRegistration: {
        column: 'pregnancy_month_at_registration',
        type: 'number',
        schema: Joi.number().integer().min(1).max(10).required(),
      },
      status: { column: 'status', schema: Joi.string().valid('active', 'closed').default('active') },
      closedOn: { column: 'closed_on', schema: calendarDate().allow(null).default(null) },
      // Estimated delivery date from the LMP date, a known EDD or the month (M2 FE-1).
      lmpDate: { column: 'lmp_date', schema: calendarDate().allow(null).default(null) },
      reportedEdd: { column: 'reported_edd', schema: calendarDate().allow(null).default(null) },
      estimatedDeliveryDate: { column: 'estimated_delivery_date', schema: calendarDate().allow(null).default(null) },
      eddBasis: { column: 'edd_basis', schema: Joi.string().valid('lmp', 'edd', 'month').allow(null).default(null) },
    },
    check(data) {
      if (data.closedOn !== null && data.status !== 'closed') return 'closedOn is only for a closed pregnancy';
      // An app from before 22 Oct 2026 sends no date: estimate it from the month as the app does now.
      if (data.estimatedDeliveryDate === null && data.eddBasis === null && data.lmpDate === null && data.reportedEdd === null) {
        Object.assign(data, { eddBasis: 'month', estimatedDeliveryDate: eddFromMonth(data.registeredOn, data.pregnancyMonthAtRegistration) });
      }
      if (data.estimatedDeliveryDate === null || data.eddBasis === null) return 'estimatedDeliveryDate and eddBasis go together';
      if ((data.eddBasis === 'lmp') !== (data.lmpDate !== null)) return 'lmpDate is given exactly when eddBasis is lmp';
      if ((data.eddBasis === 'edd') !== (data.reportedEdd !== null)) return 'reportedEdd is given exactly when eddBasis is edd';
      const [lo, hi] = GESTATION.registration_weeks;
      const weeks = weeksOn(data.estimatedDeliveryDate, data.registeredOn);
      return weeks < lo || weeks > hi ? `gestational age at registration must be ${lo}-${hi} weeks` : null;
    },
  },

  // M2 FE-2: obstetric history at registration, the baseline risk profile.
  obstetric_history: {
    parent: { field: 'womanId', table: 'women' },
    fields: {
      womanId: { column: 'woman_id', schema: reference() },
      previousPregnancies: { column: 'previous_pregnancies', type: 'number', schema: count() },
      previousCSections: { column: 'previous_c_sections', type: 'number', schema: count() },
      stillbirths: { column: 'stillbirths', type: 'number', schema: count() },
      knownConditions: { column: 'known_conditions', schema: text(1000) },
    },
    check(data) {
      if (data.previousCSections > data.previousPregnancies) return 'previousCSections cannot exceed previousPregnancies';
      if (data.stillbirths > data.previousPregnancies) return 'stillbirths cannot exceed previousPregnancies';
      return null;
    },
  },

  // M3 FE-1: one home visit with its vitals and symptoms. Units are in the
  // names and never converted in storage; blood sugar keeps the unit it was
  // recorded in.
  visits: {
    parent: { field: 'pregnancyId', table: 'pregnancies' },
    fields: {
      pregnancyId: { column: 'pregnancy_id', schema: reference() },
      visitedAt: { column: 'visited_at', type: 'timestamp', schema: Joi.date().iso().required() },
      systolicBpMmhg: { column: 'systolic_bp_mmhg', type: 'number', schema: vital('systolicBpMmhg') },
      diastolicBpMmhg: { column: 'diastolic_bp_mmhg', type: 'number', schema: vital('diastolicBpMmhg') },
      weightKg: { column: 'weight_kg', type: 'number', schema: vital('weightKg', 2) },
      temperatureC: { column: 'temperature_c', type: 'number', schema: vital('temperatureC', 1) },
      // Pulse is required (M3 FE-1): read from the BP device or counted for 30 seconds.
      pulseBpm: { column: 'pulse_bpm', type: 'number', schema: vital('pulseBpm').invalid(null).required() },
      // Optional blood sugar with its value in the unit it was recorded in, the
      // date it was measured and its source (M3 FE-1, M4 FE-1).
      bloodSugarValue: {
        column: 'blood_sugar_value',
        type: 'number',
        schema: Joi.number().precision(1).positive().allow(null).default(null),
      },
      bloodSugarUnit: {
        column: 'blood_sugar_unit',
        schema: Joi.string().valid('mmol_l', 'mg_dl').allow(null).default(null),
      },
      bloodSugarMeasuredOn: { column: 'blood_sugar_measured_on', schema: calendarDate().allow(null).default(null) },
      bloodSugarSource: {
        column: 'blood_sugar_source',
        schema: Joi.string().valid('glucometer', 'lab_report').allow(null).default(null),
      },
      fetalMovement: {
        column: 'fetal_movement',
        schema: Joi.string().valid('normal', 'reduced', 'absent').allow(null).default(null),
      },
      swelling: { column: 'swelling', schema: flag() },
      bleeding: { column: 'bleeding', schema: flag() },
      fever: { column: 'fever', schema: flag() },
      anaemiaSigns: { column: 'anaemia_signs', schema: Joi.string().valid('none', 'present', 'severe').default('none') },
      urineSymptoms: { column: 'urine_symptoms', schema: flag() },
      convulsions: { column: 'convulsions', schema: answer() },
      severeHeadache: { column: 'severe_headache', schema: answer() },
      blurredVision: { column: 'blurred_vision', schema: answer() },
      severeAbdominalPain: { column: 'severe_abdominal_pain', schema: answer() },
      fastBreathing: { column: 'fast_breathing', schema: answer() },
      feverWithWeakness: { column: 'fever_with_weakness', schema: answer() },
    },
    check(data) {
      const details = [data.bloodSugarUnit, data.bloodSugarMeasuredOn, data.bloodSugarSource];
      if (data.bloodSugarValue === null) {
        return details.every((d) => d === null) ? null : 'blood sugar details need a blood sugar value';
      }
      if (!details.every((d) => d !== null)) return 'a blood sugar value needs its unit, date and source';
      // The allowed range is in mmol/L; a mg/dL reading is compared after converting it.
      const mmol = data.bloodSugarUnit === 'mg_dl' ? data.bloodSugarValue / MG_DL_PER_MMOL_L : data.bloodSugarValue;
      const [min, max] = VISIT_ENTRY_CHECKS.bloodSugarMmolL.allowed;
      return mmol < min || mmol > max ? 'blood sugar is outside the allowed range' : null;
    },
  },
};

// Joi schema for the `data` object of one table.
function dataSchema(def) {
  const keys = Object.fromEntries(Object.entries(def.fields).map(([name, field]) => [name, field.schema]));
  return Joi.object(keys).custom((value, helpers) => {
    const problem = def.check ? def.check(value) : null;
    return problem ? helpers.message(problem) : value;
  });
}

// A value as it is stored, so a resent record can be compared with the database row.
function normalise(field, value) {
  if (value === null || value === undefined) return null;
  if (field.type === 'number') return Number(value);
  if (field.type === 'timestamp') return new Date(value).toISOString();
  return value;
}

module.exports = { TABLES, dataSchema, normalise, eddFromMonth, weeksOn };
