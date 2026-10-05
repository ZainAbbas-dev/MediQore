// Checks the synthetic data generator (P0-8, LI-10). The database tests run
// against DATABASE_URL after the migrations and roll back their data.
const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { Client } = require('pg');
const { generateSynthetic, buildSynthetic } = require('../seeds/synthetic/generate');
const { readOptions } = require('../seeds/synthetic/index');
const { DISTRICTS } = require('../seeds/synthetic/names');

const envFile = path.join(__dirname, '..', '.env');
if (fs.existsSync(envFile)) process.loadEnvFile(envFile);

const NOW = '2026-09-01T12:00:00Z';
const SMALL = { prefix: 'test', districts: 2, tehsilsPerDistrict: 1, ucsPerTehsil: 1, areasPerUc: 2, householdsPerLhw: 20, now: NOW };
const DAY = 24 * 60 * 60 * 1000;

const tablesOf = (built) => Object.fromEntries(built.tables);

describe('synthetic data (in memory)', () => {
  const data = tablesOf(buildSynthetic({ ...SMALL, seed: 3 }, 'hash'));

  test('the same seed gives the same rows, another seed different ones', () => {
    assert.deepEqual(buildSynthetic({ ...SMALL, seed: 3 }, 'hash'), buildSynthetic({ ...SMALL, seed: 3 }, 'hash'));
    const other = tablesOf(buildSynthetic({ ...SMALL, seed: 4 }, 'hash'));
    assert.notEqual(other.households[0].id, data.households[0].id);
  });

  test('builds the requested geography, accounts and households', () => {
    assert.equal(data.districts.length, 2);
    assert.equal(data.areas.length, 4);
    assert.equal(data.lhw_profiles.length, 4); // one LHW per area
    assert.equal(data.supervisor_areas.length, 4); // each area has its tehsil's supervisor
    assert.equal(data.users.filter((u) => u.role === 'admin').length, 1);
    assert.equal(data.households.length, 4 * 20);
    assert.ok(data.women.length > 0 && data.visits.length >= data.women.length);
    assert.ok(data.users.every((u) => u.username.startsWith('test.')));
  });

  test('every record is made by its LHW, in the LHW area, as a UUID v4', () => {
    const lhwArea = new Map(data.lhw_profiles.map((p) => [p.user_id, p.area_id]));
    const uuidV4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
    for (const table of ['households', 'women', 'pregnancies', 'obstetric_history', 'visits']) {
      for (const row of data[table]) {
        assert.match(row.id, uuidV4);
        assert.equal(lhwArea.get(row.created_by), row.area_id, `${table} ${row.id}`);
      }
    }
  });

  test('a DHQ hospital per district and a THQ per tehsil, near their district, made by the admin (M10 FE-3)', () => {
    const admin = data.users.find((u) => u.role === 'admin');
    assert.deepEqual(data.hospitals.map((h) => h.facility_type).sort(), ['DHQ', 'DHQ', 'THQ', 'THQ']);
    const centres = DISTRICTS.slice(0, 2);
    for (const h of data.hospitals) {
      assert.equal(h.created_by, admin.id);
      assert.match(h.phone, /^0000-\d{7}$/);
      assert.ok(data.districts.some((d) => d.id === h.district_id));
      assert.ok(centres.some((d) => Math.abs(h.latitude - d.lat) < 0.4 && Math.abs(h.longitude - d.lng) < 0.4), h.name);
    }
  });

  test('patient IDs are the LHW code plus a counter, and unique', () => {
    const codes = new Map(data.lhw_profiles.map((p) => [p.user_id, p.lhw_code]));
    for (const woman of data.women) {
      assert.match(woman.patient_code, new RegExp(`^${codes.get(woman.created_by)}-\\d{4}$`));
      assert.match(woman.contact_number, /^0000-\d{7}$/); // never a real phone number
    }
    assert.equal(new Set(data.women.map((w) => w.patient_code)).size, data.women.length);
  });

  test('households sit near their district', () => {
    const centres = DISTRICTS.slice(0, 2);
    for (const h of data.households) {
      assert.ok(centres.some((d) => Math.abs(h.latitude - d.lat) < 0.35 && Math.abs(h.longitude - d.lng) < 0.35),
        `${h.household_number} at ${h.latitude}, ${h.longitude}`);
    }
  });

  test('dates follow each other and never pass "now"', () => {
    const now = new Date(NOW);
    const households = new Map(data.households.map((h) => [h.id, h]));
    const women = new Map(data.women.map((w) => [w.id, w]));
    const pregnancies = new Map(data.pregnancies.map((p) => [p.id, p]));
    for (const w of data.women) {
      assert.ok(w.created_on_device > households.get(w.household_id).created_on_device);
    }
    for (const p of data.pregnancies) {
      const monthsSince = Math.floor((now - women.get(p.woman_id).created_on_device) / (30 * DAY));
      assert.ok(p.pregnancy_month_at_registration + monthsSince <= 9, 'still pregnant today');
    }
    for (const v of data.visits) {
      assert.ok(v.visited_at >= pregnancies.get(v.pregnancy_id).created_on_device);
      assert.ok(v.visited_at <= now);
    }
  });

  test('vitals are stored in the schema units and plausible ranges', () => {
    for (const v of data.visits) {
      assert.ok(v.systolic_bp_mmhg >= 85 && v.systolic_bp_mmhg <= 200);
      assert.ok(v.diastolic_bp_mmhg >= 50 && v.diastolic_bp_mmhg < v.systolic_bp_mmhg);
      assert.ok(v.temperature_c >= 36 && v.temperature_c <= 40); // °C, not °F
      assert.ok(v.pulse_bpm >= 60 && v.pulse_bpm <= 130);
      assert.ok(v.weight_kg >= 40 && v.weight_kg <= 120);
      assert.ok(v.blood_sugar_mmol_l === null || (v.blood_sugar_mmol_l >= 3.5 && v.blood_sugar_mmol_l <= 15)); // mmol/L
    }
    assert.ok(data.visits.some((v) => v.blood_sugar_mmol_l === null), 'blood sugar is optional');
  });

  test('a few visits wait in the conflict queue, each on the same Pakistan day as a stored visit (M3 FE-2)', () => {
    const big = tablesOf(buildSynthetic({ ...SMALL, seed: 3, householdsPerLhw: 60 }, 'hash'));
    assert.ok(big.sync_conflicts.length > 0);
    const visits = new Map(big.visits.map((v) => [v.id, v]));
    const pakistanDay = (date) => new Date(new Date(date).getTime() + 5 * 60 * 60 * 1000).toISOString().slice(0, 10);
    for (const c of big.sync_conflicts) {
      const existing = visits.get(c.existing_record_id);
      const incoming = JSON.parse(c.incoming_payload);
      assert.equal(c.status, 'pending');
      assert.equal(incoming.data.pregnancyId, existing.pregnancy_id);
      assert.equal(c.area_id, existing.area_id);
      assert.equal(pakistanDay(incoming.data.visitedAt), pakistanDay(existing.visited_at));
      assert.ok(!visits.has(incoming.id), 'the held visit is not stored');
    }
  });
});

describe('seed:synthetic options', () => {
  test('reads the counts and flags', () => {
    const { overrides, reset, allowRemote } = readOptions(['--seed', '9', '--districts', '3', '--households', '5', '--reset']);
    assert.equal(overrides.seed, 9);
    assert.equal(overrides.districts, 3);
    assert.equal(overrides.householdsPerLhw, 5);
    assert.equal(reset, true);
    assert.equal(allowRemote, false);
  });

  test('rejects bad values', () => {
    assert.throws(() => readOptions(['--districts', '9']), /--districts/);
    assert.throws(() => readOptions(['--households', 'many']), /--households/);
    assert.throws(() => readOptions(['--prefix', 'Bad Prefix']), /--prefix/);
  });
});

describe('synthetic data (in PostgreSQL)', () => {
  let client;

  before(async () => {
    assert.ok(process.env.DATABASE_URL, 'Set DATABASE_URL (see db/.env.example) and run npm run migrate:up first');
    client = new Client({ connectionString: process.env.DATABASE_URL });
    await client.connect();
  });

  after(async () => {
    await client?.end();
  });

  test('loads into the schema, and the server numbers every synced row', async () => {
    await client.query('BEGIN');
    try {
      const { counts, accounts } = await generateSynthetic(client, { ...SMALL, prefix: 'pgtest', seed: 11 });
      assert.equal(accounts.lhws.length, 4);

      for (const table of ['households', 'women', 'pregnancies', 'obstetric_history', 'visits', 'hospitals']) {
        const { rows: [row] } = await client.query(
          `SELECT count(*)::int AS n, count(server_seq)::int AS numbered, count(synced_at)::int AS synced
           FROM ${table} WHERE created_by IN (SELECT id FROM users WHERE username LIKE 'pgtest.%')`,
        );
        assert.deepEqual(row, { n: counts[table], numbered: counts[table], synced: counts[table] }, table);
      }

      // A supervisor sees households only through the assigned areas.
      const { rows: [scoped] } = await client.query(
        `SELECT count(*)::int AS n FROM households h
         JOIN supervisor_areas sa ON sa.area_id = h.area_id AND sa.deleted_at IS NULL
         JOIN users u ON u.id = sa.supervisor_id
         WHERE u.username = $1`, ['pgtest.sup.01']);
      assert.equal(scoped.n, 2 * SMALL.householdsPerLhw);
    } finally {
      await client.query('ROLLBACK');
    }
  });
});
