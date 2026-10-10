// P0-11: checks the Clinical Rules Table v0 against the scope and the roadmap,
// and runs the shared test cases (one or more per rule). Run with `node --test`
// from clinical-rules/.
const { describe, test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const rules = require('../conditions');

const root = path.join(__dirname, '..');
const table = JSON.parse(fs.readFileSync(path.join(root, 'clinical-rules.json'), 'utf8'));
const cases = JSON.parse(fs.readFileSync(path.join(root, 'test-cases.json'), 'utf8'));

// A duration such as { "weeks": 6 } in days, counting a month as 30 days, for ordering only.
function approxDays(duration) {
  if (duration === null) return null;
  const [[unit, n]] = Object.entries(duration);
  return n * { days: 1, weeks: 7, months: 30 }[unit];
}

function isDuration(value) {
  if (value === null) return true;
  const entries = Object.entries(value);
  return entries.length === 1 && ['days', 'weeks', 'months'].includes(entries[0][0]) && Number.isInteger(entries[0][1]) && entries[0][1] >= 0;
}

describe('table metadata', () => {
  test('is version 0, marked "pending clinical review" and unsigned (LI-12)', () => {
    assert.match(table.version, /^0\.\d+\.\d+$/);
    assert.equal(table.status, 'pending clinical review');
    assert.equal(table.sign_off.clinical_advisor, null);
    assert.equal(table.sign_off.signed_on, null);
    assert.match(table.effective_from, /^\d{4}-\d{2}-\d{2}$/);
    assert.equal(cases.rules_version, table.version, 'test-cases.json names the table version it was written for');
  });

  test('stores one unit per value, as the roadmap lists them', () => {
    assert.deepEqual(table.units, {
      blood_pressure: 'mmHg',
      pulse: 'beats/min',
      temperature: '°C',
      blood_sugar: 'mmol/L',
      haemoglobin: 'g/dL',
      weight: 'kg',
      muac: 'mm',
      height: 'cm',
      respiratory_rate: 'breaths/min',
    });
  });

  test('every reference used is listed, and every listed reference is used', () => {
    const used = new Set();
    (function walk(node, key) {
      if (Array.isArray(node)) node.forEach((n) => walk(n, key));
      else if (node && typeof node === 'object') Object.entries(node).forEach(([k, v]) => walk(v, k));
      else if ((key === 'reference' || key === 'references') && typeof node === 'string') used.add(node);
    })({ ...table, references: undefined });
    for (const key of used) assert.ok(table.references[key], `reference ${key} is not listed`);
    for (const key of Object.keys(table.references)) assert.ok(used.has(key), `reference ${key} is never used`);
  });
});

describe('visit entry checks (M3 FE-1)', () => {
  const { vitals, pulse_counter: counter, blood_sugar_conversion: sugar } = table.visit_entry_checks;

  test('systolic BP outside 60-250 asks for confirmation, as the roadmap says', () => {
    assert.deepEqual(vitals.systolicBpMmhg.plausible, [60, 250]);
  });

  test('every plausible range lies inside its allowed range', () => {
    for (const [field, range] of Object.entries(vitals)) {
      const [lo, hi] = range.allowed;
      const [plo, phi] = range.plausible;
      assert.ok(lo < plo && plo < phi && phi < hi, `${field}: ${range.plausible} inside ${range.allowed}`);
      assert.ok(Number.isInteger(range.decimals) && range.decimals >= 0);
    }
  });

  test('the pulse counter counts 30 seconds and doubles', () => {
    assert.equal(counter.count_seconds * counter.multiplier, 60);
    assert.deepEqual([counter.count_seconds, counter.multiplier], [30, 2]);
  });

  test('mg/dL converts to mmol/L with factor 18', () => {
    assert.equal(sugar.mg_dl_per_mmol_l, 18.0);
  });
});

describe('maternal danger-sign rules (M4 FE-4)', () => {
  const section = table.maternal_risk;

  test('rule ids are unique and every rule reads only declared fields with valid values', () => {
    const all = [...section.rules, ...section.flags];
    assert.equal(new Set(all.map((r) => r.id)).size, all.length);
    for (const rule of all) {
      for (const { field, op, value } of rules.comparisons(rule.when)) {
        const type = section.fields[field];
        assert.ok(type, `${rule.id} reads undeclared field ${field}`);
        if (Array.isArray(type)) {
          const values = op === 'in' ? value : [value];
          for (const v of values) assert.ok(type.includes(v), `${rule.id}: ${field} has no value ${v}`);
        } else {
          assert.equal(typeof value, type, `${rule.id}: ${field} compares with a ${type}`);
        }
      }
    }
  });

  test('every rule ends in Emergency or Yellow, and the scope list is complete', () => {
    for (const rule of section.rules) assert.ok(['emergency', 'yellow'].includes(rule.result), rule.id);
    assert.deepEqual(section.rules.map((r) => r.id).sort(), [
      'absent_or_reduced_fetal_movement',
      'convulsions',
      'fast_or_difficult_breathing',
      'fever_with_weakness',
      'high_fever_with_danger_sign',
      'raised_bp',
      'raised_bp_with_symptom',
      'severe_abdominal_pain',
      'severe_anaemia_signs',
      'severe_headache_with_blurred_vision',
      'severe_hypertension',
      'vaginal_bleeding',
    ]);
    assert.equal(section.rules.find((r) => r.id === 'raised_bp').result, 'yellow');
  });

  test('swelling is a flag that never changes the level', () => {
    const swelling = section.flags.find((f) => f.id === 'swelling');
    assert.equal(swelling.changes_level, false);
  });

  test('every rule and flag has at least one shared test case that fires it', () => {
    const fired = new Set(cases.maternal_visits.flatMap((c) => [...c.triggered, ...c.flags]));
    for (const rule of [...section.rules, ...section.flags]) assert.ok(fired.has(rule.id), `no test case fires ${rule.id}`);
  });

  for (const c of cases.maternal_visits) {
    test(`case: ${c.name}`, () => {
      const result = rules.maternalRuleResult(table, c.visit);
      assert.deepEqual(result, { result: c.result, triggered: c.triggered, flags: c.flags });
    });
  }

  for (const c of cases.final_levels) {
    test(`final level: model ${c.model} + rules ${c.rule_result} = ${c.level}`, () => {
      assert.equal(rules.finalLevel(table, c.model, c.rule_result), c.level);
    });
  }
});

describe('obstetric history and anaemia flags (M2 FE-2, M6 FE-2)', () => {
  test('flags never change the risk colour in v0', () => {
    assert.equal(table.obstetric_history_flags.changes_level, false);
    assert.equal(table.anaemia.changes_level, false);
  });

  test('"Previous C-section", named by the scope, is a flag', () => {
    assert.ok(table.obstetric_history_flags.flags.some((f) => f.id === 'previous_c_section'));
  });

  test('flags read only declared fields', () => {
    for (const flag of table.obstetric_history_flags.flags) {
      for (const { field } of rules.comparisons(flag.when)) {
        assert.ok(table.obstetric_history_flags.fields[field], `${flag.id} reads ${field}`);
      }
    }
  });

  for (const c of cases.obstetric_histories) {
    test(`obstetric flags: ${c.flags.join(', ') || 'none'}`, () => {
      assert.deepEqual(rules.obstetricFlags(table, c.history), c.flags);
    });
  }

  for (const c of cases.haemoglobin) {
    test(`Hb ${c.hb_g_dl} g/dL is ${c.level}`, () => {
      assert.equal(rules.anaemiaLevel(table, c.hb_g_dl), c.level);
    });
  }
});

describe('pregnancy outcomes, ANC and TT (M6 FE-1, FE-4)', () => {
  test('the stillbirth boundary is 28 weeks (WHO)', () => {
    assert.equal(table.pregnancy_outcomes.stillbirth_min_gestational_weeks, 28);
  });

  for (const c of cases.pregnancy_outcomes) {
    test(`outcome at ${c.gestational_weeks} weeks, live birth ${c.live_birth}: ${c.type}`, () => {
      assert.equal(rules.outcomeType(table, { liveBirth: c.live_birth, gestationalWeeks: c.gestational_weeks }), c.type);
    });
  }

  test('ANC has eight contacts, the first by 12 weeks and the last at 40 (WHO 2016)', () => {
    const weeks = table.anc_schedule.contacts_at_weeks;
    assert.equal(weeks.length, 8);
    assert.equal(weeks[0], 12);
    assert.equal(weeks.at(-1), 40);
    for (let i = 1; i < weeks.length; i++) assert.ok(weeks[i] > weeks[i - 1]);
  });

  test('TT doses are numbered 1-5 with valid intervals', () => {
    const doses = table.tetanus_toxoid.doses;
    assert.deepEqual(doses.map((d) => d.dose_number), [1, 2, 3, 4, 5]);
    assert.equal(doses[0].min_interval, null);
    for (const d of doses) assert.ok(isDuration(d.min_interval));
  });
});

describe('EPI schedule (M8 FE-1)', () => {
  const epi = table.epi_schedule;
  const key = (d) => `${d.antigen}-${d.dose_number}`;

  test('has every dose the scope lists, and only those', () => {
    assert.deepEqual(epi.doses.map(key).sort(), [
      'BCG-1',
      'HepB-0',
      'IPV-1', 'IPV-2',
      'MR-1', 'MR-2',
      'OPV-0', 'OPV-1', 'OPV-2', 'OPV-3',
      'PCV-1', 'PCV-2', 'PCV-3',
      'Penta-1', 'Penta-2', 'Penta-3',
      'Rota-1', 'Rota-2',
      'TCV-1',
    ]);
  });

  test('each dose has a valid number, ages and interval', () => {
    for (const d of epi.doses) {
      for (const field of ['min_age', 'recommended_age', 'min_interval', 'max_age']) {
        assert.ok(isDuration(d[field]), `${key(d)}.${field}`);
      }
      assert.ok(d.min_age && d.recommended_age, `${key(d)} needs a minimum and recommended age`);
      assert.ok(approxDays(d.min_age) <= approxDays(d.recommended_age), `${key(d)}: minimum age after recommended age`);
      if (d.max_age) assert.ok(approxDays(d.max_age) >= approxDays(d.recommended_age), `${key(d)}: maximum age`);
      assert.equal(typeof d.rollout_by_area, 'boolean');
    }
  });

  test('doses of one antigen follow each other, spaced at least by the minimum interval', () => {
    const byAntigen = Map.groupBy(epi.doses, (d) => d.antigen);
    for (const [antigen, doses] of byAntigen) {
      const numbers = doses.map((d) => d.dose_number);
      assert.deepEqual(numbers, [...numbers].sort((a, b) => a - b), `${antigen} doses are in order`);
      for (let i = 1; i < doses.length; i++) {
        const gap = approxDays(doses[i].recommended_age) - approxDays(doses[i - 1].recommended_age);
        if (doses[i].min_interval) assert.ok(gap >= approxDays(doses[i].min_interval), `${key(doses[i])} gap`);
      }
    }
  });

  test('the Hep B birth dose is switched on per area', () => {
    const hepb = epi.doses.find((d) => key(d) === 'HepB-0');
    assert.equal(hepb.rollout_by_area, true);
    assert.ok(Array.isArray(hepb.enabled_area_ids));
  });

  test('the zero-dose indicator is Penta-1', () => {
    assert.deepEqual([epi.zero_dose_indicator.antigen, epi.zero_dose_indicator.dose_number], ['Penta', 1]);
    assert.ok(epi.doses.some((d) => key(d) === 'Penta-1'));
  });

  test('the schedule has a version and an effective date', () => {
    assert.ok(epi.schedule_version);
    assert.match(epi.effective_from, /^\d{4}-\d{2}-\d{2}$/);
  });
});

describe('nutrition and IMCI (M9)', () => {
  test('MUAC bands cover every value once: SAM below 115, MAM 115 to under 125, normal from 125', () => {
    const bands = table.nutrition.muac_bands_mm;
    assert.deepEqual(bands.map((b) => b.class), ['sam', 'mam', 'normal']);
    for (let mm = 60; mm <= 200; mm++) {
      assert.equal(bands.filter((b) => rules.band([b], mm)).length, 1, `${mm} mm falls in exactly one band`);
    }
    assert.deepEqual(table.nutrition.muac_age_months, [6, 59]);
  });

  test('Hb bands cover every value once', () => {
    for (let tenth = 30; tenth <= 180; tenth++) {
      const hb = tenth / 10;
      assert.equal(table.anaemia.bands_g_dl.filter((b) => rules.band([b], hb)).length, 1, `${hb} g/dL`);
    }
  });

  for (const c of cases.muac) {
    test(`MUAC ${c.muac_mm} mm, oedema ${c.oedema}: ${c.class}`, () => {
      assert.equal(rules.malnutritionClass(table, { muacMm: c.muac_mm, oedema: c.oedema }), c.class);
    });
  }

  test('fast breathing is 50 or more from 2 to 12 months and 40 or more from 12 months to 5 years (IMCI 2014)', () => {
    assert.deepEqual(table.imci.fast_breathing.map((r) => [r.from_months, r.below_months, r.breaths_per_minute_at_least]), [
      [2, 12, 50],
      [12, 60, 40],
    ]);
    assert.equal(table.imci.respiratory_rate_count_seconds, 60);
  });

  for (const c of cases.imci_breathing) {
    test(`IMCI: ${c.age_months} months, ${c.breaths_per_minute}/min, indrawing ${c.chest_indrawing}: ${c.class}`, () => {
      assert.equal(
        rules.pneumoniaClass(table, {
          ageMonths: c.age_months,
          breathsPerMinute: c.breaths_per_minute,
          chestIndrawing: c.chest_indrawing,
          generalDangerSigns: c.general_danger_signs,
        }),
        c.class,
      );
    });
  }

  test('dehydration signs are all declared', () => {
    for (const row of table.imci.dehydration) {
      for (const sign of row.signs) assert.ok(table.imci.dehydration_signs.includes(sign), sign);
    }
  });

  for (const c of cases.imci_dehydration) {
    test(`IMCI dehydration with ${c.signs.join(', ') || 'no signs'}: ${c.class}`, () => {
      assert.equal(rules.dehydrationClass(table, c.signs), c.class);
    });
  }
});
