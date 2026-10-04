const fs = require('node:fs');
const path = require('node:path');
const { TABLES } = require('../src/sync/tables');

// M3 FE-1: the app's range config (mobile/assets/clinical/visit_ranges.json)
// lets the LHW save only what this server accepts. Its "allowed" range must be
// the server's bounds, or a visit saved offline would be refused at sync.
const CONFIG = path.join(__dirname, '..', '..', 'mobile', 'assets', 'clinical', 'visit_ranges.json');
const config = JSON.parse(fs.readFileSync(CONFIG, 'utf8'));

// The bounds and decimals of a vital's Joi schema.
function bounds(field) {
  const { rules } = TABLES.visits.fields[field].schema.describe();
  const arg = (name) => rules.find((rule) => rule.name === name)?.args.limit;
  return { min: arg('min'), max: arg('max'), decimals: rules.some((rule) => rule.name === 'integer') ? 0 : arg('precision') };
}

describe('visit ranges shared with the app (M3 FE-1)', () => {
  test('every vital with a server bound has a range in the app, and the reverse', () => {
    const vitals = Object.keys(TABLES.visits.fields).filter((name) => TABLES.visits.fields[name].type === 'number');
    expect(Object.keys(config.vitals).sort()).toEqual(vitals.sort());
  });

  test.each(Object.entries(config.vitals))('%s: allowed is the server bound, plausible lies inside it', (field, range) => {
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
