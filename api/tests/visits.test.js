const { randomUUID } = require('node:crypto');
const request = require('supertest');
const { createApp } = require('../src/app');
const { describeDb, resetDatabase, createFixtures, tokenFor, closePool, query } = require('./db');

const app = createApp();

// A registration (household, woman, pregnancy) for a fixture LHW, as the app pushes it.
function registration(code) {
  const household = { table: 'households', id: randomUUID(), createdOnDevice: '2026-10-01T09:30:00.000Z', data: { village: 'Dhok Syedan' } };
  const woman = {
    table: 'women', id: randomUUID(), createdOnDevice: '2026-10-01T09:30:00.000Z',
    data: { householdId: household.id, patientCode: code, name: 'Synthetic Woman', age: 26 },
  };
  const pregnancy = {
    table: 'pregnancies', id: randomUUID(), createdOnDevice: '2026-10-01T09:30:00.000Z',
    data: { womanId: woman.id, registeredOn: '2026-10-01', pregnancyMonthAtRegistration: 3 },
  };
  return { household, woman, pregnancy, all: [household, woman, pregnancy] };
}

// One home visit (M3 FE-1). visitedAt is UTC; Pakistan is UTC+5.
function visit(pregnancyId, visitedAt = '2026-10-04T05:00:00.000Z', data = {}) {
  return {
    table: 'visits', id: randomUUID(), createdOnDevice: visitedAt,
    data: {
      pregnancyId, visitedAt, systolicBpMmhg: 118, diastolicBpMmhg: 76, weightKg: 58.4, temperatureC: 37.1,
      pulseBpm: 84, bloodSugarValue: 94, bloodSugarUnit: 'mg_dl', bloodSugarMeasuredOn: '2026-10-03',
      bloodSugarSource: 'glucometer', fetalMovement: 'normal', swelling: false, bleeding: false, fever: false,
      anaemiaSigns: 'none', urineSymptoms: false, convulsions: false, severeHeadache: true, blurredVision: false,
      severeAbdominalPain: false, fastBreathing: false, feverWithWeakness: false, ...data,
    },
  };
}

describeDb('Module 3: visits through sync', () => {
  let ids;
  let lhwA;
  let lhwB;
  let supervisor;
  let admin;
  let pregnancyA;
  let pregnancyB;

  const push = (token, deviceId, records) =>
    request(app).post('/api/v1/sync/push').set('Authorization', `Bearer ${token}`).send({ deviceId, records });
  const pushA = (records) => push(lhwA, ids.deviceA, records);
  const outcomes = (res) => res.body.results.map((r) => r.reason || r.status);
  const visitIds = async () => (await query('SELECT id FROM visits WHERE deleted_at IS NULL')).rows.map((r) => r.id);
  const get = (token, path) => request(app).get(`/api/v1${path}`).set('Authorization', `Bearer ${token}`);

  beforeEach(async () => {
    await resetDatabase();
    ids = await createFixtures();
    lhwA = tokenFor(ids.lhwA, 'lhw', ids.deviceA);
    lhwB = tokenFor(ids.lhwB, 'lhw', ids.deviceB);
    supervisor = tokenFor(ids.supervisorA, 'supervisor');
    admin = tokenFor(ids.admin, 'admin');
    const a = registration('LHW-A-0001');
    const b = registration('LHW-B-0001');
    await pushA(a.all);
    await push(lhwB, ids.deviceB, b.all);
    pregnancyA = a.pregnancy.id;
    pregnancyB = b.pregnancy.id;
  });

  afterAll(closePool);

  describe('push and pull (M3 FE-1, FE-2)', () => {
    it('stores a visit with every vital in its unit, and pulls it back unchanged', async () => {
      const v = visit(pregnancyA);

      const res = await pushA([v]);

      expect(outcomes(res)).toEqual(['created']);
      const { rows: [row] } = await query('SELECT * FROM visits WHERE id = $1', [v.id]);
      expect(row).toMatchObject({
        area_id: ids.areaA, systolic_bp_mmhg: 118, weight_kg: '58.40', temperature_c: '37.1', pulse_bpm: 84,
        blood_sugar_value: '94.0', blood_sugar_unit: 'mg_dl', blood_sugar_measured_on: '2026-10-03',
        blood_sugar_source: 'glucometer', convulsions: false, severe_headache: true,
      });
      const pulled = await get(lhwA, '/sync/pull');
      expect(pulled.body.records.find((r) => r.id === v.id).data).toEqual(v.data);
      expect(outcomes(await pushA([v]))).toEqual(['unchanged']);
    });

    it('keeps a blood sugar in the unit it was recorded in (M3 FE-1)', async () => {
      const inMmol = visit(pregnancyA, undefined, { bloodSugarValue: 5.2, bloodSugarUnit: 'mmol_l' });

      expect(outcomes(await pushA([inMmol]))).toEqual(['created']);
      const { rows: [row] } = await query('SELECT blood_sugar_value, blood_sugar_unit FROM visits WHERE id = $1', [inMmol.id]);
      expect(row).toEqual({ blood_sugar_value: '5.2', blood_sugar_unit: 'mmol_l' });
    });

    it('stores no blood sugar details without a value, and unanswered checklist questions as null', async () => {
      const v = visit(pregnancyA, undefined, {
        bloodSugarValue: null, bloodSugarUnit: null, bloodSugarMeasuredOn: null, bloodSugarSource: null,
      });
      for (const question of ['convulsions', 'severeHeadache', 'blurredVision', 'severeAbdominalPain', 'fastBreathing', 'feverWithWeakness']) {
        delete v.data[question];
      }

      expect(outcomes(await pushA([v]))).toEqual(['created']);
      const { rows: [row] } = await query('SELECT * FROM visits WHERE id = $1', [v.id]);
      expect(row).toMatchObject({ blood_sugar_value: null, blood_sugar_source: null, convulsions: null, fever_with_weakness: null });
    });

    it('refuses a visit for a pregnancy the server does not have', async () => {
      expect(outcomes(await pushA([visit(randomUUID())]))).toEqual(['MISSING_PARENT']);
    });

    it.each([
      ['a systolic BP of 400', { systolicBpMmhg: 400 }],
      ['a temperature of 60 °C', { temperatureC: 60 }],
      ['an unknown fetal movement value', { fetalMovement: 'fast' }],
      ['an unknown anaemia value', { anaemiaSigns: 'mild' }],
      ['a visit time that is not a date', { visitedAt: 'yesterday' }],
      ['a visit without a pulse (M3 FE-1)', { pulseBpm: null }],
      ['a blood sugar without its source', { bloodSugarSource: null }],
      ['a blood sugar without its date', { bloodSugarMeasuredOn: null }],
      ['blood sugar details without a value', { bloodSugarValue: null }],
      ['a blood sugar value without its unit', { bloodSugarUnit: null }],
      ['an unknown blood sugar unit', { bloodSugarUnit: 'mg' }],
      ['a mg/dL blood sugar beyond the allowed range', { bloodSugarValue: 901 }],
      ['a mmol/L blood sugar beyond the allowed range', { bloodSugarValue: 50.1, bloodSugarUnit: 'mmol_l' }],
      ['an unknown blood sugar source', { bloodSugarSource: 'guess' }],
      ['a blood sugar date that is not a date', { bloodSugarMeasuredOn: '2026-02-30' }],
      ['a checklist answer that is not yes or no', { convulsions: 'maybe' }],
    ])('rejects %s with 400', async (_, change) => {
      const res = await pushA([visit(pregnancyA, undefined, change)]);

      expect(res.status).toBe(400);
    });
  });

  describe('two visits on one day (M3 FE-2)', () => {
    it('stores both: only an outdated edit or a likely duplicate patient goes to Conflict Review', async () => {
      const first = visit(pregnancyA, '2026-10-04T05:00:00.000Z');
      const second = visit(pregnancyA, '2026-10-04T15:00:00.000Z', { systolicBpMmhg: 150 });

      const res = await pushA([first, second]);

      expect(outcomes(res)).toEqual(['created', 'created']);
      expect((await visitIds()).sort()).toEqual([first.id, second.id].sort());
      expect((await query('SELECT count(*)::int AS n FROM sync_conflicts')).rows[0].n).toBe(0);
    });
  });

  describe('portal counts (M10 FE-1)', () => {
    it("counts registered women, this week's visits and pending conflicts in the viewer's areas", async () => {
      const now = new Date().toISOString();
      await pushA([visit(pregnancyA, now), visit(pregnancyA, now)]);
      await push(lhwB, ids.deviceB, [visit(pregnancyB, now)]);

      const mine = await get(supervisor, '/dashboard/summary');
      const all = await get(admin, '/dashboard/summary');

      expect(mine.body).toEqual({ registeredWomen: 1, visitsThisWeek: 2, pendingConflicts: 0, lhws: 1, lhwsSyncedToday: 1 });
      expect(all.body).toEqual({ registeredWomen: 2, visitsThisWeek: 3, pendingConflicts: 0, lhws: 2, lhwsSyncedToday: 2 });
      const women = await get(supervisor, '/women');
      expect(women.body.women[0].visits).toEqual({ count: 2, lastVisitAt: now });
    });
  });
});
