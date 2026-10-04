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
      pulseBpm: 84, bloodSugarMmolL: 5.2, fetalMovement: 'normal', swelling: false, bleeding: false, fever: false,
      anaemiaSigns: 'none', urineSymptoms: false, ...data,
    },
  };
}

describeDb('Module 3: visits, same-day conflicts and the review queue', () => {
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
  const resolve = (token, id, resolution) =>
    request(app).post(`/api/v1/conflicts/${id}/resolve`).set('Authorization', `Bearer ${token}`).send({ resolution });

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
      expect(row).toMatchObject({ area_id: ids.areaA, systolic_bp_mmhg: 118, weight_kg: '58.40', temperature_c: '37.1' });
      const pulled = await get(lhwA, '/sync/pull');
      expect(pulled.body.records.find((r) => r.id === v.id).data).toEqual(v.data);
      expect(outcomes(await pushA([v]))).toEqual(['unchanged']);
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
    ])('rejects %s with 400', async (_, change) => {
      const res = await pushA([visit(pregnancyA, undefined, change)]);

      expect(res.status).toBe(400);
    });
  });

  describe('same woman, same day (M3 FE-2, LI-7)', () => {
    it('holds a second visit on the same Pakistan day for the supervisor, and audits it', async () => {
      const first = visit(pregnancyA, '2026-10-04T05:00:00.000Z'); // 10:00 in Pakistan
      const second = visit(pregnancyA, '2026-10-04T15:00:00.000Z', { systolicBpMmhg: 150 }); // 20:00, same day
      await pushA([first]);

      const res = await pushA([second]);

      expect(res.body.results[0]).toMatchObject({ id: second.id, status: 'conflict' });
      expect(await visitIds()).toEqual([first.id]);
      const { rows: [conflict] } = await query('SELECT * FROM sync_conflicts');
      expect(conflict).toMatchObject({
        id: res.body.results[0].conflictId, status: 'pending', table_name: 'visits', area_id: ids.areaA,
        incoming_record_id: second.id, existing_record_id: first.id, submitted_by: ids.lhwA, device_id: ids.deviceA,
      });
      const { rows: audit } = await query(`SELECT entity_id FROM audit_log WHERE action = 'sync_conflict'`);
      expect(audit).toEqual([{ entity_id: second.id }]);
    });

    it('answers a resend of the held visit with the same conflict', async () => {
      const first = visit(pregnancyA);
      const second = visit(pregnancyA);
      await pushA([first]);
      const held = await pushA([second]);

      const again = await pushA([second]);

      expect(again.body.results[0]).toEqual(held.body.results[0]);
      expect((await query('SELECT count(*)::int AS n FROM sync_conflicts')).rows[0].n).toBe(1);
    });

    it('also catches two visits in one batch, but not a visit after midnight in Pakistan', async () => {
      const morning = visit(pregnancyA, '2026-10-04T04:00:00.000Z');
      const evening = visit(pregnancyA, '2026-10-04T18:30:00.000Z'); // 23:30 in Pakistan
      const nextDay = visit(pregnancyA, '2026-10-04T19:30:00.000Z'); // 00:30 the next day in Pakistan

      const res = await pushA([morning, evening, nextDay]);

      expect(outcomes(res)).toEqual(['created', 'conflict', 'created']);
    });
  });

  describe('the review queue (M10 base)', () => {
    let first;
    let second;
    let conflictId;

    beforeEach(async () => {
      first = visit(pregnancyA, '2026-10-04T05:00:00.000Z');
      second = visit(pregnancyA, '2026-10-04T09:00:00.000Z', { systolicBpMmhg: 150 });
      await pushA([first]);
      conflictId = (await pushA([second])).body.results[0].conflictId;
    });

    it("shows a supervisor their areas' conflicts with both visits side by side", async () => {
      await push(lhwB, ids.deviceB, [visit(pregnancyB), visit(pregnancyB)]); // a conflict in area B

      const res = await get(supervisor, '/conflicts');

      expect(res.status).toBe(200);
      expect(res.body.conflicts).toHaveLength(1);
      expect(res.body.conflicts[0]).toMatchObject({
        id: conflictId, status: 'pending', reason: 'same_parent_same_day', areaName: 'Area A',
        submittedBy: { lhwCode: 'LHW-A' }, woman: { name: 'Synthetic Woman', patientCode: 'LHW-A-0001' },
        incoming: { id: second.id, data: { systolicBpMmhg: 150 } },
        existing: { id: first.id, deleted: false, data: { systolicBpMmhg: 118, visitedAt: first.data.visitedAt } },
      });
      expect((await get(admin, '/conflicts')).body.conflicts).toHaveLength(2);
    });

    it('keep both: the held visit is stored and reaches the phone at its next pull', async () => {
      const res = await resolve(supervisor, conflictId, 'keep_both');

      expect(res.body.conflict).toMatchObject({ status: 'resolved', resolution: 'keep_both', resolvedBy: 'Test supervisor.a' });
      expect((await visitIds()).sort()).toEqual([first.id, second.id].sort());
      const pulled = await get(lhwA, '/sync/pull');
      expect(pulled.body.records.find((r) => r.id === second.id)).toMatchObject({ deleted: false });
      const { rows: [row] } = await query('SELECT created_by FROM visits WHERE id = $1', [second.id]);
      expect(row.created_by).toBe(ids.lhwA);
    });

    it('keep existing: the held visit is kept on record as deleted, and the phone drops it', async () => {
      await resolve(supervisor, conflictId, 'keep_existing');

      expect(await visitIds()).toEqual([first.id]);
      const pulled = await get(lhwA, '/sync/pull');
      expect(pulled.body.records.find((r) => r.id === second.id)).toMatchObject({ deleted: true });
    });

    it('keep incoming: the held visit replaces the earlier one, which is deleted and audited', async () => {
      await resolve(supervisor, conflictId, 'keep_incoming');

      expect(await visitIds()).toEqual([second.id]);
      const { rows: audit } = await query(
        `SELECT action, entity_id FROM audit_log WHERE details->>'conflictId' = $1::text OR entity_id = $1::uuid ORDER BY id`,
        [conflictId],
      );
      // The whole trail: held, stored, the earlier visit deleted, resolved.
      expect(audit.map((a) => a.action)).toEqual(['sync_conflict', 'create', 'delete', 'sync_conflict']);
    });

    it('resolves a conflict once', async () => {
      await resolve(supervisor, conflictId, 'keep_both');

      const again = await resolve(supervisor, conflictId, 'keep_existing');

      expect(again.status).toBe(409);
      expect(again.body.error.code).toBe('ALREADY_RESOLVED');
      expect((await get(supervisor, '/conflicts?status=resolved')).body.conflicts).toHaveLength(1);
      expect((await get(supervisor, '/conflicts')).body.conflicts).toHaveLength(0);
    });

    it("keeps supervisors out of other areas' conflicts, and LHWs out of the queue", async () => {
      const inB = (await push(lhwB, ids.deviceB, [visit(pregnancyB), visit(pregnancyB)])).body.results[1].conflictId;

      expect((await resolve(supervisor, inB, 'keep_both')).status).toBe(404);
      expect((await resolve(lhwA, conflictId, 'keep_both')).status).toBe(403);
      expect((await resolve(supervisor, conflictId, 'merge')).status).toBe(400);
    });
  });

  describe('portal counts (M10 FE-1)', () => {
    it("counts registered women, this week's visits and pending conflicts in the viewer's areas", async () => {
      const now = new Date().toISOString();
      await pushA([visit(pregnancyA, now), visit(pregnancyA, now)]); // the second waits for review
      await push(lhwB, ids.deviceB, [visit(pregnancyB, now)]);

      const mine = await get(supervisor, '/dashboard/summary');
      const all = await get(admin, '/dashboard/summary');

      expect(mine.body).toEqual({ registeredWomen: 1, visitsThisWeek: 1, pendingConflicts: 1 });
      expect(all.body).toEqual({ registeredWomen: 2, visitsThisWeek: 2, pendingConflicts: 1 });
      const women = await get(supervisor, '/women');
      expect(women.body.women[0].visits).toEqual({ count: 1, lastVisitAt: now });
    });
  });
});
