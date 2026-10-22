const fs = require('node:fs');
const path = require('node:path');
const { TABLES, dataSchema } = require('../src/sync/tables');

// M3 FE-1, P0-11: the visit form's ranges live in the Clinical Rules Table,
// which the app bundles (mobile/assets/clinical/clinical-rules.json) and this
// server reads. Its "allowed" range must be the server's bounds, or a visit
// saved offline would be refused at sync.
const TABLE = path.join(__dirname, '..', '..', 'clinical-rules', 'clinical-rules.json');
const APP_COPY = path.join(__dirname, '..', '..', 'mobile', 'assets', 'clinical', 'clinical-rules.json');
const config = JSON.parse(fs.readFileSync(TABLE, 'utf8')).visit_entry_checks;

// The bounds and decimals of a vital's Joi schema.
function bounds(field) {
  const { rules } = TABLES.visits.fields[field].schema.describe();
  const arg = (name) => rules.find((rule) => rule.name === name)?.args.limit;
  return { min: arg('min'), max: arg('max'), decimals: rules.some((rule) => rule.name === 'integer') ? 0 : arg('precision') };
}

describe('visit ranges shared with the app (M3 FE-1)', () => {
  test('the app bundles the same Clinical Rules Table the server reads', () => {
    expect(fs.readFileSync(APP_COPY, 'utf8')).toBe(fs.readFileSync(TABLE, 'utf8'));
  });

  // Blood sugar keeps the unit it was recorded in (M3 FE-1), so its range (in
  // mmol/L) is checked after converting; see the test below.
  const fixedUnitVitals = Object.entries(config.vitals).filter(([field]) => field !== 'bloodSugarMmolL');

  test('every vital with a server bound has a range in the app, and the reverse', () => {
    const vitals = Object.keys(TABLES.visits.fields)
      .filter((name) => TABLES.visits.fields[name].type === 'number' && name !== 'bloodSugarValue');
    expect(fixedUnitVitals.map(([field]) => field).sort()).toEqual(vitals.sort());
  });

  test('blood sugar is refused only outside the allowed range, in either unit', () => {
    const schema = dataSchema(TABLES.visits);
    const [min, max] = config.vitals.bloodSugarMmolL.allowed;
    const factor = config.blood_sugar_conversion.mg_dl_per_mmol_l;
    const visit = (value, unit) => ({
      pregnancyId: '3f2b8c1e-8d3a-4b5c-9e6f-1a2b3c4d5e6f', visitedAt: '2026-10-04T05:00:00.000Z', pulseBpm: 80,
      bloodSugarValue: value, bloodSugarUnit: unit, bloodSugarMeasuredOn: '2026-10-04', bloodSugarSource: 'glucometer',
    });
    expect(schema.validate(visit(max, 'mmol_l')).error).toBeUndefined();
    expect(schema.validate(visit(max + 0.1, 'mmol_l')).error).toBeDefined();
    expect(schema.validate(visit(max * factor, 'mg_dl')).error).toBeUndefined();
    expect(schema.validate(visit(max * factor + 1, 'mg_dl')).error).toBeDefined();
    expect(schema.validate(visit(min * factor - 1, 'mg_dl')).error).toBeDefined();
  });

  test.each(fixedUnitVitals)('%s: allowed is the server bound, plausible lies inside it', (field, range) => {
    const server = bounds(field);
    expect(range.allowed).toEqual([server.min, server.max]);
    expect(range.decimals).toBeLessThanOrEqual(server.decimals);
    expect(range.plausible[0]).toBeGreaterThanOrEqual(range.allowed[0]);
    expect(range.plausible[1]).toBeLessThanOrEqual(range.allowed[1]);
    expect(range.plausible[0]).toBeLessThan(range.plausible[1]);
  });

  test('systolic BP outside 60-250 asks for confirmation (the roadmap example)', () => {
    expect(config.vitals.systolicBpMmhg.plausible).toEqual([60, 250]);
  });
});
