const request = require('supertest');
const { createApp } = require('../src/app');
const { describeDb, resetDatabase, createFixtures, tokenFor, closePool, query } = require('./db');

const app = createApp();
const asOf = '2026-11-23T07:15:00Z';

describeDb('M10 FE-4 weekly LHW inactivity', () => {
  let ids;
  let supervisor;
  let admin;
  let pregnancyId;
  const exclusions = (id, week = '') => `/inactivity/${id}/exclusions${week ? `/${week}` : ''}`;
  const call = (method, path, token = supervisor) =>
    request(app)[method](`/api/v1${path}`).set('Authorization', `Bearer ${token}`);
  const setLastSync = (at) => query('UPDATE devices SET last_records_sync_at = $1 WHERE id = $2', [at, ids.deviceA]);

  async function visit(at, count = 1, deleted = false) {
    await query(
      `INSERT INTO visits (area_id, created_by, pregnancy_id, visited_at, deleted_at)
       SELECT $1, $2, $3, $4, CASE WHEN $6 THEN now() END FROM generate_series(1, $5::integer)`,
      [ids.areaA, ids.lhwA, pregnancyId, at, count, deleted],
    );
  }

  async function load() {
    const { getInactivity } = require('../src/services/inactivity.service');
    const result = await getInactivity({ id: ids.supervisorA, role: 'supervisor' }, [ids.lhwA, ids.lhwB], { now: asOf });
    expect(result.weekStart).toBe('2026-11-16');
    expect(result.lhws.map(({ id }) => id)).toEqual([ids.lhwA]);
    return result.lhws[0];
  }

  async function baseline(counts = [8, 8, 8, 8, 8, 8]) {
    const mondays = ['2026-10-05', '2026-10-12', '2026-10-19', '2026-10-26', '2026-11-02', '2026-11-09'];
    for (const [idx, day] of mondays.entries()) await visit(`${day}T05:00:00Z`, counts[idx]);
  }

  beforeEach(async () => {
    await resetDatabase();
    ids = await createFixtures();
    supervisor = tokenFor(ids.supervisorA, 'supervisor');
    admin = tokenFor(ids.admin, 'admin');
    await query("UPDATE devices SET activated_at = '2026-10-04T19:00:00Z', last_records_sync_at = $2 WHERE id = $1", [ids.deviceA, asOf]);
    const { rows: [pregnancy] } = await query(
      `WITH household AS (
         INSERT INTO households (area_id, created_by, village) VALUES ($1, $2, 'Test') RETURNING id
       ), woman AS (
         INSERT INTO women (area_id, created_by, household_id, patient_code, name, age)
         SELECT $1, $2, id, 'LHW-A-0001', 'Synthetic', 25 FROM household RETURNING id
       )
       INSERT INTO pregnancies (area_id, created_by, woman_id, registered_on, pregnancy_month_at_registration, estimated_delivery_date, edd_basis)
       SELECT $1, $2, id, '2026-10-05', 3, '2027-04-05', 'month' FROM woman RETURNING id`,
      [ids.areaA, ids.lhwA],
    );
    pregnancyId = pregnancy.id;
  });

  afterAll(closePool);

  it('lists only assigned LHWs and denies access to an LHW account', async () => {
    const response = await call('get', '/inactivity');
    expect(response.status).toBe(200);
    expect(response.body.lhws.map(({ id }) => id)).toEqual([ids.lhwA]);
    expect((await call('get', '/inactivity', admin)).body.lhws.map(({ id }) => id)).toEqual([ids.lhwA, ids.lhwB]);
    expect((await call('get', '/inactivity', tokenFor(ids.lhwA, 'lhw', ids.deviceA))).status).toBe(403);
  });

  it('counts visits by the Pakistan week at both boundaries and excludes deleted visits', async () => {
    await baseline();
    await visit('2026-11-15T18:59:59Z');
    await visit('2026-11-15T19:00:00Z');
    await visit('2026-11-22T18:59:59Z');
    await visit('2026-11-22T19:00:00Z');
    await visit('2026-11-18T05:00:00Z', 3, true);

    expect((await load()).inactivity).toMatchObject({ status: 'unusual_inactivity', visits: 2, historyWeeks: 6 });
  });

  it('does not count visits from a transferred LHW’s former unassigned area', async () => {
    await visit('2026-11-18T05:00:00Z', 4);
    await query('UPDATE lhw_profiles SET area_id = $1 WHERE user_id = $2', [ids.areaB, ids.lhwA]);
    await query('UPDATE supervisor_areas SET area_id = $1 WHERE supervisor_id = $2', [ids.areaB, ids.supervisorA]);

    const { getInactivity } = require('../src/services/inactivity.service');
    const data = await getInactivity({ id: ids.supervisorA, role: 'supervisor' }, [ids.lhwA], { now: asOf });
    expect(data.lhws[0].inactivity.visits).toBe(0);
  });

  it('requires sync at or after Pakistan Monday before evaluating the previous week', async () => {
    await baseline();
    await setLastSync('2026-11-22T18:59:59Z');
    expect(await load()).toMatchObject({
      lastSyncAt: new Date('2026-11-22T18:59:59Z'),
      inactivity: { status: 'not_synced', visits: null },
    });

    await setLastSync('2026-11-22T19:00:00Z');
    expect((await load()).inactivity.status).toBe('unusual_inactivity');
  });

  it('requires a completed records pull before a configuration-only request counts as synced', async () => {
    await setLastSync(null);
    const lhw = tokenFor(ids.lhwA, 'lhw', ids.deviceA);
    await call('get', '/sync/config', lhw).expect(200);
    expect((await load()).inactivity.status).toBe('not_synced');
    await call('get', '/sync/pull?since=0', lhw).expect(200);
    expect((await load()).inactivity).toMatchObject({ status: 'active', visits: 0 });
  });

  it('includes zero-visit weeks in the baseline after activation', async () => {
    await baseline([8, 8, 8, 8, 0, 0]);

    expect((await load()).inactivity).toMatchObject({ status: 'active', visits: 0, historyWeeks: 6 });
  });

  it('requires a drop strictly larger than two population standard deviations', async () => {
    await baseline([5, 5, 5, 9, 9, 9]);
    await visit('2026-11-18T05:00:00Z', 3);

    expect((await load()).inactivity).toMatchObject({ status: 'active', visits: 3, historyWeeks: 6 });
  });

  it('requires a drop of at least three visits even with zero variance', async () => {
    await baseline([4, 4, 4, 4, 4, 4]);
    await visit('2026-11-18T05:00:00Z', 2);
    expect((await load()).inactivity.status).toBe('active');

    await query("UPDATE visits SET deleted_at = now() WHERE id = (SELECT id FROM visits WHERE visited_at = '2026-11-18T05:00:00Z' LIMIT 1)");
    expect((await load()).inactivity.status).toBe('unusual_inactivity');
  });

  it('honors configured history and visit thresholds', async () => {
    await baseline();
    await visit('2026-11-18T05:00:00Z');
    const original = process.env;
    try {
      process.env = { ...original, INACTIVITY_MIN_HISTORY_WEEKS: '7' };
      expect((await load()).inactivity.status).toBe('insufficient_history');

      process.env = { ...original, INACTIVITY_MIN_VISIT_DROP: '8' };
      expect((await load()).inactivity.status).toBe('active');

      process.env = original;
      expect((await load()).inactivity.status).toBe('unusual_inactivity');
    } finally {
      process.env = original;
    }
  });

  it('excludes marked weeks and restores evaluation after a supervisor removes the exclusion', async () => {
    await baseline();
    await call('put', exclusions(ids.lhwA, '2026-10-12')).send({ kind: 'campaign' }).expect(200);
    expect((await load()).inactivity).toMatchObject({ status: 'insufficient_history', historyWeeks: 5 });
    await call('put', exclusions(ids.lhwA, '2026-11-16')).send({ kind: 'leave' }).expect(200);
    expect((await load()).inactivity).toMatchObject({ status: 'excluded', exclusion: 'leave' });

    await call('delete', exclusions(ids.lhwA, '2026-11-16')).expect(204);
    await call('delete', exclusions(ids.lhwA, '2026-10-12')).expect(204);
    expect((await load()).inactivity.status).toBe('unusual_inactivity');
  });

  it('rejects out-of-scope exclusions and invalid calendar dates', async () => {
    await call('get', exclusions(ids.lhwB)).expect(404);
    await call('put', exclusions(ids.lhwB, '2026-11-16')).send({ kind: 'leave' }).expect(404);
    await call('delete', exclusions(ids.lhwB, '2026-11-16')).expect(404);
    await call('put', exclusions(ids.lhwA, '2026-11-17')).send({ kind: 'leave' }).expect(400);
    await call('put', exclusions(ids.lhwA, '2026-02-30')).send({ kind: 'leave' }).expect(400);
    await call('put', exclusions(ids.lhwA, '2026-11-16'), admin).send({ kind: 'leave' }).expect(403);
  });

  it('audits create, edit and removal, with no repeated audit entry for retries', async () => {
    const week = '2026-11-16';
    const first = await call('put', exclusions(ids.lhwA, week)).send({ kind: 'leave' }).expect(200);
    const repeat = await call('put', exclusions(ids.lhwA, week)).send({ kind: 'leave' }).expect(200);
    expect(first.body.exclusion).toMatchObject({ weekStart: week, kind: 'leave', markedBy: ids.supervisorA });
    expect(repeat.body.exclusion).toEqual(first.body.exclusion);

    await call('put', exclusions(ids.lhwA, week)).send({ kind: 'campaign' }).expect(200);
    const listed = await call('get', exclusions(ids.lhwA)).expect(200);
    expect(listed.body.exclusions).toEqual([{ ...first.body.exclusion, kind: 'campaign' }]);

    await call('delete', exclusions(ids.lhwA, week)).expect(204);
    await call('delete', exclusions(ids.lhwA, week)).expect(204);
    expect((await call('get', exclusions(ids.lhwA))).body.exclusions).toEqual([]);

    const { rows } = await query(
      "SELECT user_id, action, details FROM audit_log WHERE entity_type = 'leave_and_campaign_weeks' ORDER BY id",
    );
    expect(rows.map(({ action }) => action)).toEqual(['create', 'edit', 'delete']);
    expect(rows).toEqual(rows.map(({ action, details }) => ({
      user_id: ids.supervisorA,
      action,
      details: { ...details, lhwId: ids.lhwA, areaId: ids.areaA, weekStart: week },
    })));
    expect(rows[1].details).toMatchObject({ previousKind: 'leave', kind: 'campaign' });
  });
});
