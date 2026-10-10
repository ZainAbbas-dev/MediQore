// Pregnant women (M2 FE-1), obstetric history (M2 FE-2) and home visits with
// vitals, symptoms, blood sugar details and the danger-sign checklist (M3 FE-1). About 4 in 10 households have a registered
// pregnancy.
//
// Each woman gets a made-up profile (mostly healthy, some borderline, a few
// unwell) so the dashboard and, later, the risk model demos have variety. These
// numbers only shape synthetic data; they are not clinical thresholds, which
// live in the versioned clinical config (M4 FE-4).
const { WOMEN, MEN, FAMILY, KNOWN_CONDITIONS } = require('../names');
const { round } = require('../random');

const DAY = 24 * 60 * 60 * 1000;
const pad = (n, width) => String(n).padStart(width, '0');
const dateOnly = (date) => date.toISOString().slice(0, 10);

const PROFILES = {
  // [mean, sd, min, max] per vital, chances per symptom.
  well: {
    systolic: [112, 9, 90, 135], diastolic: [72, 7, 55, 88], pulse: [82, 7, 62, 100], sugar: [5.0, 0.6, 3.8, 6.8],
    fever: 0.02, bleeding: 0.01, swelling: 0.05, urine: 0.05, dangerSign: 0.005,
    anaemia: { none: 90, present: 10 }, fetal: { normal: 96, reduced: 4 },
  },
  borderline: {
    systolic: [132, 8, 115, 150], diastolic: [85, 6, 70, 98], pulse: [90, 8, 68, 110], sugar: [6.6, 1.0, 4.5, 9.0],
    fever: 0.05, bleeding: 0.03, swelling: 0.2, urine: 0.1, dangerSign: 0.02,
    anaemia: { none: 70, present: 27, severe: 3 }, fetal: { normal: 88, reduced: 10, absent: 2 },
  },
  unwell: {
    systolic: [152, 12, 135, 190], diastolic: [98, 8, 85, 120], pulse: [100, 10, 75, 130], sugar: [8.5, 2.0, 5.0, 15.0],
    fever: 0.12, bleeding: 0.12, swelling: 0.45, urine: 0.15, dangerSign: 0.06,
    anaemia: { none: 50, present: 38, severe: 12 }, fetal: { normal: 75, reduced: 20, absent: 5 },
  },
};

function build({ random, now }, homes) {
  const women = [];
  const pregnancies = [];
  const obstetricHistory = [];
  const visits = [];
  const counters = new Map(); // LHW code -> last patient number (M2 FE-1: LHW code + local counter)

  for (const { row: household, lhw } of homes.byId.values()) {
    if (!random.chance(0.4)) continue;

    const profile = PROFILES[random.weighted({ well: 70, borderline: 20, unwell: 10 })];
    const vital = (key, digits = 0) => round(random.normal(...profile[key]), digits);
    const base = { area_id: household.area_id, created_by: lhw.userId };

    // Registered after the household was first recorded, at least a week ago,
    // and early enough that the pregnancy is still under 9 months today.
    const month = random.int(1, 8);
    const householdAgeDays = Math.floor((now - household.created_on_device) / DAY);
    const daysAgo = random.int(7, Math.max(7, Math.min(150, householdAgeDays - 1, (9 - month) * 30)));
    const registeredAt = new Date(now.getTime() - daysAgo * DAY);
    registeredAt.setUTCHours(random.int(4, 11), random.int(0, 59), 0, 0); // 9:00–16:59 Pakistan time

    const number = (counters.get(lhw.lhwCode) || 0) + 1;
    counters.set(lhw.lhwCode, number);
    const family = random.pick(FAMILY);
    const age = Math.round(random.normal(27, 5, 18, 42));
    const woman = {
      id: random.uuid(),
      ...base,
      created_on_device: registeredAt,
      household_id: household.id,
      patient_code: `${lhw.lhwCode}-${pad(number, 4)}`,
      name: `${random.pick(WOMEN)} ${family}`,
      age,
      husband_name: `${random.pick(MEN)} ${family}`,
      contact_number: `0000-${pad(random.int(0, 9999999), 7)}`, // never a real number
    };
    women.push(woman);

    const pregnancy = {
      id: random.uuid(),
      ...base,
      created_on_device: registeredAt,
      woman_id: woman.id,
      registered_on: dateOnly(registeredAt),
      pregnancy_month_at_registration: month,
      status: 'active',
    };
    pregnancies.push(pregnancy);

    const previous = random.int(0, Math.min(6, Math.floor((age - 18) / 3) + 1));
    const cSections = previous ? random.int(0, Math.min(previous, profile === PROFILES.well ? 1 : 2)) : 0;
    obstetricHistory.push({
      id: random.uuid(),
      ...base,
      created_on_device: registeredAt,
      woman_id: woman.id,
      previous_pregnancies: previous,
      previous_c_sections: cSections,
      stillbirths: previous > cSections && random.chance(profile === PROFILES.unwell ? 0.2 : 0.05) ? 1 : 0,
      known_conditions: random.chance(profile === PROFILES.well ? 0.05 : 0.3) ? random.pick(KNOWN_CONDITIONS) : null,
    });

    // The first visit is on the registration day, then one every 2–5 weeks.
    const startWeight = random.normal(58, 9, 40, 95);
    for (let visitedAt = registeredAt; visitedAt <= now; visitedAt = new Date(visitedAt.getTime() + random.int(14, 35) * DAY)) {
      const monthNow = month + Math.floor((visitedAt - registeredAt) / (30 * DAY));
      const fever = random.chance(profile.fever);
      const sugar = random.chance(0.4) ? vital('sugar', 1) : null; // optional reading
      visits.push({
        id: random.uuid(),
        ...base,
        created_on_device: visitedAt,
        pregnancy_id: pregnancy.id,
        visited_at: visitedAt,
        systolic_bp_mmhg: vital('systolic'),
        diastolic_bp_mmhg: vital('diastolic'),
        weight_kg: round(startWeight + Math.max(0, monthNow - 3) * 1.6 + random.normal(0, 0.4), 2),
        temperature_c: fever ? round(random.normal(38.4, 0.4, 37.8, 39.8), 1) : round(random.normal(36.8, 0.2, 36.2, 37.4), 1),
        pulse_bpm: vital('pulse'),
        blood_sugar_mmol_l: sugar,
        blood_sugar_entered_unit: sugar === null ? null : 'mmol_l',
        blood_sugar_measured_on: sugar === null ? null : dateOnly(visitedAt),
        blood_sugar_source: sugar === null ? null : random.weighted({ glucometer: 85, lab_report: 15 }),
        fetal_movement: monthNow < 5 ? null : random.weighted(profile.fetal),
        swelling: random.chance(profile.swelling),
        bleeding: random.chance(profile.bleeding),
        fever,
        anaemia_signs: random.weighted(profile.anaemia),
        urine_symptoms: random.chance(profile.urine),
        // Yes/no danger-sign checklist (M3 FE-1).
        convulsions: random.chance(profile.dangerSign),
        severe_headache: random.chance(profile.dangerSign * 2),
        blurred_vision: random.chance(profile.dangerSign),
        severe_abdominal_pain: random.chance(profile.dangerSign),
        fast_breathing: random.chance(profile.dangerSign),
        fever_with_weakness: fever && random.chance(0.3),
      });
    }
  }

  return { women, pregnancies, obstetricHistory, visits };
}

module.exports = { build };
