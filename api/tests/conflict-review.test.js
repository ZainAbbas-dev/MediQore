// M3 FE-2, M10 FE-3: record versions, edits made on an older version, possible
// duplicate patients and the supervisor's Conflict Review page.
const { randomUUID } = require('node:crypto');
const request = require('supertest');
const { createApp } = require('../src/app');
const { describeDb, resetDatabase, createFixtures, tokenFor, closePool, query } = require('./db');

const app = createApp();

function registration({ code, householdId = randomUUID(), name = 'Synthetic Woman', husband = 'Synthetic Husband' }) {
  const household = { table: 'households', id: householdId, createdOnDevice: '2026-10-01T09:30:00.000Z', data: { village: 'Dhok Syedan' } };
  const woman = {
    table: 'women', id: randomUUID(), createdOnDevice: '2026-10-01T09:30:00.000Z',
    data: { householdId, patientCode: code, name, age: 26, husbandName: husband },
  };
  const pregnancy = {
    table: 'pregnancies', id: randomUUID(), createdOnDevice: '2026-10-01T09:30:00.000Z',
    data: { womanId: woman.id, registeredOn: '2026-10-01', pregnancyMonthAtRegistration: 3, eddBasis: 'month', estimatedDeliveryDate: '2027-04-23' },
  };
  const history = {
    table: 'obstetric_history', id: randomUUID(), createdOnDevice: '2026-10-01T09:30:00.000Z',
    data: { womanId: woman.id, previousPregnancies: 1 },
  };
  return { household, woman, pregnancy, history };
}

function visit(pregnancyId) {
  return {
    table: 'visits', id: randomUUID(), createdOnDevice: '2026-10-04T05:00:00.000Z',
    data: { pregnancyId, visitedAt: '2026-10-04T05:00:00.000Z', systolicBpMmhg: 118, diastolicBpMmhg: 76, pulseBpm: 84 },
  };
}

describeDb('Conflict Review: versions and possible duplicates (M3 FE-2, M10 FE-3)', () => {
  let ids;
  let lhwA;
  let supervisor;

  const push = (records) =>
    request(app).post('/api/v1/sync/push').set('Authorization', `Bearer ${lhwA}`).send({ deviceId: ids.deviceA, records });
  const get = (token, path) => request(app).get(`/api/v1${path}`).set('Authorization', `Bearer ${token}`);
  const resolve = (id, resolution) =>
    request(app).post(`/api/v1/conflicts/${id}/resolve`).set('Authorization', `Bearer ${supervisor}`).send({ resolution });

  beforeEach(async () => {
    await resetDatabase();
    ids = await createFixtures();
    lhwA = tokenFor(ids.lhwA, 'lhw', ids.deviceA);
    supervisor = tokenFor(ids.supervisorA, 'supervisor');
  });

  afterAll(closePool);

  describe('versions', () => {
    let household;

    beforeEach(async () => {
      household = registration({ code: 'LHW-A-01-0001' }).household;
      await push([household]);
    });

    it('a new record is version 1, each accepted edit raises it, and pull carries it', async () => {
      const created = await push([household]);
      expect(created.body.results[0]).toMatchObject({ status: 'unchanged', version: 1 });

      const edit = { ...household, baseVersion: 1, data: { ...household.data, latitude: 33.6, longitude: 73.1 } };
      const res = await push([edit]);

      expect(res.body.results[0]).toMatchObject({ status: 'updated', version: 2 });
      const pulled = await get(lhwA, '/sync/pull');
      expect(pulled.body.records.find((r) => r.id === household.id)).toMatchObject({ version: 2, data: { latitude: 33.6 } });
    });

    it('a resend is acknowledged again even with an old base version, never a conflict', async () => {
      const edit = { ...household, baseVersion: 1, data: { ...household.data, village: 'Changed' } };
      await push([edit]);

      const again = await push([edit]);

      expect(again.body.results[0]).toMatchObject({ status: 'unchanged', version: 2 });
      expect((await query('SELECT count(*)::int AS n FROM sync_conflicts')).rows[0].n).toBe(0);
    });

    describe('an edit made on an older version', () => {
      let stale;
      let conflictId;

      beforeEach(async () => {
        await push([{ ...household, baseVersion: 1, data: { ...household.data, village: 'Second phone' } }]);
        stale = { ...household, baseVersion: 1, data: { ...household.data, village: 'Stale edit' } };
        const res = await push([stale]);
        expect(res.body.results[0]).toMatchObject({ status: 'conflict' });
        conflictId = res.body.results[0].conflictId;
      });

      it('is not applied, waits on the Conflict Review page and is audited', async () => {
        const { rows: [row] } = await query('SELECT village, version FROM households WHERE id = $1', [household.id]);
        expect(row).toEqual({ village: 'Second phone', version: 2 });

        const listed = await get(supervisor, '/conflicts');
        expect(listed.body.conflicts[0]).toMatchObject({
          id: conflictId, reason: 'outdated_edit', table: 'households', baseVersion: 1, existingVersion: 2,
          resolutions: ['keep_server', 'use_device'],
          incoming: { data: { village: 'Stale edit' } }, existing: { version: 2, data: { village: 'Second phone' } },
        });
        const { rows: audit } = await query(`SELECT entity_id FROM audit_log WHERE action = 'sync_conflict'`);
        expect(audit).toEqual([{ entity_id: household.id }]);
      });

      it('a resend returns the same pending conflict', async () => {
        const again = await push([stale]);

        expect(again.body.results[0]).toMatchObject({ status: 'conflict', conflictId });
        expect((await query('SELECT count(*)::int AS n FROM sync_conflicts')).rows[0].n).toBe(1);
      });

      it("keep_server: the server's version comes back to the phone at its next pull", async () => {
        const before = (await get(lhwA, '/sync/pull')).body.nextSince;

        expect((await resolve(conflictId, 'keep_server')).body.conflict).toMatchObject({ status: 'resolved', resolution: 'keep_server' });

        const pulled = await get(lhwA, `/sync/pull?since=${before}`);
        expect(pulled.body.records).toEqual([expect.objectContaining({ id: household.id, version: 3, data: expect.objectContaining({ village: 'Second phone' }) })]);
      });

      it("use_device: the phone's edit becomes the new version", async () => {
        await resolve(conflictId, 'use_device');

        const { rows: [row] } = await query('SELECT village, version FROM households WHERE id = $1', [household.id]);
        expect(row).toEqual({ village: 'Stale edit', version: 3 });
      });

      it('accepts only the decisions that fit the reason', async () => {
        const res = await resolve(conflictId, 'same_person');

        expect(res.status).toBe(400);
      });
    });
  });

  describe('possible duplicates', () => {
    let first;
    let second;
    let conflictId;

    beforeEach(async () => {
      first = registration({ code: 'LHW-A-01-0001' });
      second = registration({ code: 'LHW-A-02-0001', householdId: first.household.id, name: '  synthetic  WOMAN ', husband: 'synthetic husband' });
      await push([first.household, first.woman, first.pregnancy, first.history, visit(first.pregnancy.id)]);
      const res = await push([second.woman, second.pregnancy, second.history, visit(second.pregnancy.id)]);
      expect(res.body.results.map((r) => r.status)).toEqual(['created', 'created', 'created', 'created']);
      conflictId = res.body.results[0].possibleDuplicate;
    });

    it('stores both women and lists the newer one for review (same name, husband and household)', async () => {
      expect(conflictId).toBeDefined();
      const listed = await get(supervisor, '/conflicts');
      expect(listed.body.conflicts[0]).toMatchObject({
        id: conflictId, reason: 'possible_duplicate', table: 'women', resolutions: ['different_people', 'same_person'],
        woman: { patientCode: 'LHW-A-01-0001' }, incoming: { id: second.woman.id, deleted: false }, existing: { id: first.woman.id },
      });
    });

    it('is not flagged for a different husband or another household', async () => {
      const otherHusband = registration({ code: 'LHW-A-01-0002', householdId: first.household.id, husband: 'Another Husband' });
      const otherHome = registration({ code: 'LHW-A-01-0003' });

      const res = await push([otherHusband.woman, otherHome.household, otherHome.woman]);

      expect(res.body.results.every((r) => r.possibleDuplicate === undefined)).toBe(true);
    });

    it('different_people keeps both', async () => {
      await resolve(conflictId, 'different_people');

      const { rows } = await query('SELECT id FROM women WHERE deleted_at IS NULL');
      expect(rows).toHaveLength(2);
    });

    it('same_person moves her visits to the earlier record and deletes the newer one, audited', async () => {
      await resolve(conflictId, 'same_person');

      const { rows: women } = await query('SELECT id FROM women WHERE deleted_at IS NULL');
      expect(women).toEqual([{ id: first.woman.id }]);
      const { rows: visits } = await query('SELECT pregnancy_id FROM visits WHERE deleted_at IS NULL');
      expect(visits.map((v) => v.pregnancy_id)).toEqual([first.pregnancy.id, first.pregnancy.id]);
      const { rows: pregnancies } = await query('SELECT id FROM pregnancies WHERE deleted_at IS NULL');
      expect(pregnancies).toEqual([{ id: first.pregnancy.id }]);
      const { rows: audit } = await query(
        `SELECT action, entity_type FROM audit_log WHERE details->>'conflictId' = $1 ORDER BY id`, [conflictId],
      );
      expect(audit).toEqual([
        { action: 'sync_conflict', entity_type: 'women' },
        { action: 'edit', entity_type: 'visits' },
        { action: 'delete', entity_type: 'pregnancies' },
        { action: 'delete', entity_type: 'obstetric_history' },
        { action: 'delete', entity_type: 'women' },
      ]);
    });
  });

  it('still decides a visit held by the earlier same-day rule', async () => {
    const reg = registration({ code: 'LHW-A-01-0001' });
    await push([reg.household, reg.woman, reg.pregnancy]);
    // Held payloads were stored after validation, with every default filled in.
    const held = visit(reg.pregnancy.id);
    Object.assign(held.data, { swelling: false, bleeding: false, fever: false, anaemiaSigns: 'none', urineSymptoms: false });
    const { rows: [conflict] } = await query(
      `INSERT INTO sync_conflicts (area_id, table_name, incoming_record_id, incoming_payload, reason, submitted_by, device_id)
       VALUES ($1, 'visits', $2, $3, 'same_parent_same_day', $4, $5) RETURNING id`,
      [ids.areaA, held.id, JSON.stringify(held), ids.lhwA, ids.deviceA],
    );

    const res = await resolve(conflict.id, 'keep_both');

    expect(res.status).toBe(200);
    expect((await query('SELECT 1 FROM visits WHERE id = $1', [held.id])).rowCount).toBe(1);
  });
});
