const Joi = require('joi');

// Tables that devices may push and pull through /sync, with the fields the
// device sends (camelCase) and the column each maps to. Only tables listed here
// can be synced, and their names are the only identifiers ever placed in SQL.
// Add a table here when its module is built, together with its tests.
//
// `parent` names the record a row belongs to (a woman's household, a
// pregnancy's woman). The parent must already be on the server and in the same
// area, so the device pushes parents first. Pull order can still bring a child
// before its parent (an edited parent gets a higher server_seq), so devices
// must not require the parent when they apply a pulled row.
//
// Every listed table has the sync base columns (id, server_seq, area_id,
// created_by, created_on_device, synced_at, deleted_at); see docs/schema-v1.md.

const text = (max) => Joi.string().trim().max(max).empty('').allow(null).default(null);
const coordinate = (limit) => Joi.number().min(-limit).max(limit).precision(6).allow(null).default(null);
const reference = () => Joi.string().guid({ version: 'uuidv4' }).required();
const count = () => Joi.number().integer().min(0).max(30).default(0);

// A calendar date as YYYY-MM-DD (DATE columns are read back as the same text, see db/pool.js).
const calendarDate = () =>
  Joi.string()
    .pattern(/^\d{4}-\d{2}-\d{2}$/)
    .custom((value, helpers) => {
      const date = new Date(`${value}T00:00:00Z`);
      return !Number.isNaN(date.getTime()) && date.toISOString().startsWith(value) ? value : helpers.error('any.invalid');
    });

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

  // M2 FE-1: registered woman. The patient ID is the LHW code plus a counter
  // kept on the phone, so it is unique without a connection.
  women: {
    parent: { field: 'householdId', table: 'households' },
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
    },
    check(data) {
      return data.closedOn !== null && data.status !== 'closed' ? 'closedOn is only for a closed pregnancy' : null;
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
  return field.type === 'number' ? Number(value) : value;
}

module.exports = { TABLES, dataSchema, normalise };
