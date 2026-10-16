// M10 FE-1 (Phase 1 base): the dashboard cards, LHW visit counts, last sync and
// last login, the filter options of the dashboard, the household map filtered by
// district, Union Council, LHW and time period, and a woman's visits.
// Supervisors see only their areas.
const { randomUUID } = require('node:crypto');
const request = require('supertest');
const { createApp } = require('../src/app');
const { describeDb, resetDatabase, createFixtures, tokenFor, closePool, query } = require('./db');

const app = createApp();

// A household, a woman and her pregnancy, as the app pushes them (M2).
function registration(code, village) {
  const household = { table: 'households', id: randomUUID(), createdOnDevice: '2026-10-01T09:30:00.000Z', data: { village, latitude: 33.6, longitude: 73.0 } };
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

const visit = (pregnancyId, visitedAt) => ({
  table: 'visits', id: randomUUID(), createdOnDevice: visitedAt,
  data: { pregnancyId, visitedAt, systolicBpMmhg: 118, diastolicBpMmhg: 76, pulseBpm: 84 },
});

describeDb('dashboard: LHW activity and map filters (M10 FE-1)', () => {
  let ids;
  let supervisor;
  let admin;
  let a;
  let b;
  const get = (token, path) => request(app).get(`/api/v1${path}`).set('Authorization', `Bearer ${token}`);
  const push = (userId, deviceId, records) =>
    request(app).post('/api/v1/sync/push').set('Authorization', `Bearer ${tokenFor(userId, 'lhw', deviceId)}`).send({ deviceId, records });
  const placeOf = async (areaId) => (await query(
    `SELECT uc.id AS uc_id, t.district_id FROM areas a JOIN union_councils uc ON uc.id = a.union_council_id
     JOIN tehsils t ON t.id = uc.tehsil_id WHERE a.id = $1`,
    [areaId],
  )).rows[0];

  beforeAll(async () => {
    await resetDatabase();
    ids = await createFixtures();
    supervisor = tokenFor(ids.supervisorA, 'supervisor');
    admin = tokenFor(ids.admin, 'admin');

    a = registration('LHW-A-0001', 'Village A');
    b = registration('LHW-B-0001', 'Village B');
    const now = new Date();
    const daysAgo = (n) => new Date(now.getTime() - n * 86400000).toISOString();
    await push(ids.lhwA, ids.deviceA, [...a.all, visit(a.pregnancy.id, now.toISOString()), visit(a.pregnancy.id, daysAgo(40))]);
    await push(ids.lhwB, ids.deviceB, b.all);
    // LHW B's household reached the server long ago. The trigger would stamp
    // the update with now(), so it is off for this one change.
    await query('ALTER TABLE households DISABLE TRIGGER households_server_seq');
    await query("UPDATE households SET synced_at = now() - interval '60 days' WHERE id = $1", [b.household.id]);
    await query('ALTER TABLE households ENABLE TRIGGER households_server_seq');
    await query("UPDATE users SET last_login_at = '2026-10-03T08:00:00Z' WHERE id = $1", [ids.lhwA]);
  });

  afterAll(closePool);

  it('counts each LHW\'s visits and registrations, with last visit, last sync and last login', async () => {
    const res = await get(admin, '/dashboard/lhw-activity');

    expect(res.status).toBe(200);
    const [lhwA, lhwB] = res.body.lhws;
    expect(lhwA).toMatchObject({
      lhwCode: 'LHW-A', area: 'Area A', unionCouncil: 'UC', district: 'Area A District', isActive: true,
      visitsThisWeek: 1, visitsTotal: 2, womenRegistered: 1, lastLoginAt: '2026-10-03T08:00:00.000Z',
    });
    expect(lhwA.lastVisitAt).not.toBeNull();
    expect(lhwA.lastSyncAt).not.toBeNull();
    expect(lhwB).toMatchObject({ lhwCode: 'LHW-B', visitsThisWeek: 0, visitsTotal: 0, womenRegistered: 1, lastVisitAt: null, lastLoginAt: null });
  });

  it('shows a supervisor only the LHWs of their areas, and filters by district', async () => {
    const own = await get(supervisor, '/dashboard/lhw-activity');
    const { district_id: districtB } = await placeOf(ids.areaB);
    const filtered = await get(admin, `/dashboard/lhw-activity?districtId=${districtB}`);

    expect(own.body.lhws.map((l) => l.lhwCode)).toEqual(['LHW-A']);
    expect(filtered.body.lhws.map((l) => l.lhwCode)).toEqual(['LHW-B']);
  });

  it('offers the districts, Union Councils and LHWs within the viewer\'s areas as filters', async () => {
    const forSupervisor = (await get(supervisor, '/dashboard/filters')).body;
    const forAdmin = (await get(admin, '/dashboard/filters')).body;

    expect(forSupervisor.districts.map((d) => d.name)).toEqual(['Area A District']);
    expect(forSupervisor.unionCouncils).toHaveLength(1);
    expect(forSupervisor.lhws.map((l) => l.lhwCode)).toEqual(['LHW-A']);
    expect(forAdmin.districts.map((d) => d.name)).toEqual(['Area A District', 'Area B District']);
    expect(forAdmin.lhws.map((l) => l.lhwCode)).toEqual(['LHW-A', 'LHW-B']);
    expect(forAdmin.lhws[0]).toMatchObject({ fullName: 'Test lhw.a', districtId: forAdmin.districts[0].id });
  });

  it('filters the household map by district, Union Council, LHW and time period', async () => {
    const villages = async (path) => (await get(admin, path)).body.households.map((h) => h.village).sort();
    const { district_id: districtA, uc_id: ucA } = await placeOf(ids.areaA);

    expect(await villages('/households')).toEqual(['Village A', 'Village B']);
    expect(await villages(`/households?districtId=${districtA}`)).toEqual(['Village A']);
    expect(await villages(`/households?unionCouncilId=${ucA}`)).toEqual(['Village A']);
    expect(await villages(`/households?lhwId=${ids.lhwB}`)).toEqual(['Village B']);
    expect(await villages('/households?days=30')).toEqual(['Village A']);
    const [row] = (await get(admin, `/households?lhwId=${ids.lhwA}`)).body.households;
    expect(row).toMatchObject({ registeredBy: 'LHW-A', unionCouncilName: 'UC' });
  });

  it('keeps a supervisor inside their areas whatever the filter', async () => {
    const res = await get(supervisor, `/households?lhwId=${ids.lhwB}`);
    expect(res.body.households).toEqual([]);
  });

  it('narrows the cards by district, Union Council and LHW, inside the viewer\'s areas', async () => {
    const { district_id: districtB } = await placeOf(ids.areaB);
    const { uc_id: ucA } = await placeOf(ids.areaA);
    const cards = async (token, path) => (await get(token, `/dashboard/summary${path}`)).body;

    expect(await cards(admin, '')).toMatchObject({ registeredWomen: 2, visitsThisWeek: 1, lhws: 2 });
    expect(await cards(admin, `?districtId=${districtB}`)).toMatchObject({ registeredWomen: 1, visitsThisWeek: 0, lhws: 1 });
    expect(await cards(admin, `?unionCouncilId=${ucA}`)).toMatchObject({ registeredWomen: 1, visitsThisWeek: 1, lhws: 1 });
    expect(await cards(admin, `?lhwId=${ids.lhwA}`)).toMatchObject({ registeredWomen: 1, visitsThisWeek: 1, lhws: 1 });
    expect(await cards(supervisor, '')).toMatchObject({ registeredWomen: 1, lhws: 1 });
    expect(await cards(supervisor, `?lhwId=${ids.lhwB}`)).toMatchObject({ registeredWomen: 0, visitsThisWeek: 0, lhws: 0 });
  });

  it('filters LHW activity by LHW', async () => {
    const res = await get(admin, `/dashboard/lhw-activity?lhwId=${ids.lhwB}`);
    expect(res.body.lhws.map((l) => l.lhwCode)).toEqual(['LHW-B']);
  });

  it('lists a woman\'s visits, latest by server number first, only in the viewer\'s areas', async () => {
    const res = await get(supervisor, `/women/${a.woman.id}/visits`);

    expect(res.status).toBe(200);
    expect(res.body.visits).toHaveLength(2);
    const [latest, earlier] = res.body.visits;
    expect(latest.serverSeq).toBeGreaterThan(earlier.serverSeq);
    expect(new Date(latest.visitedAt) < new Date(earlier.visitedAt)).toBe(true); // pushed later, visited earlier
    expect(latest).toMatchObject({
      pregnancyId: a.pregnancy.id, systolicBpMmhg: 118, pulseBpm: 84, bloodSugarMmolL: null,
      convulsions: null, recordedBy: { lhwCode: 'LHW-A', fullName: 'Test lhw.a' },
    });
    expect((await get(supervisor, `/women/${b.woman.id}/visits`)).status).toBe(404);
    expect((await get(admin, `/women/${b.woman.id}/visits`)).body.visits).toEqual([]);
    expect((await get(admin, '/women/nope/visits')).status).toBe(400);
    expect((await get(tokenFor(ids.lhwA, 'lhw', ids.deviceA), `/women/${a.woman.id}/visits`)).status).toBe(403);
  });

  it('is for supervisors and admins, with validated filters', async () => {
    expect((await get(tokenFor(ids.lhwA, 'lhw', ids.deviceA), '/dashboard/lhw-activity')).status).toBe(403);
    expect((await get(admin, '/dashboard/lhw-activity?districtId=nope')).status).toBe(400);
    expect((await get(admin, '/households?days=0')).status).toBe(400);
    expect((await get(admin, '/dashboard/summary?lhwId=nope')).status).toBe(400);
  });

  it('counts a pull with nothing new as a sync: last sync and "LHWs synced today"', async () => {
    // LHW B last sent records 60 days ago and her phone has not synced since.
    for (const table of ['households', 'women', 'pregnancies']) {
      await query(`ALTER TABLE ${table} DISABLE TRIGGER ${table}_server_seq`);
      await query(`UPDATE ${table} SET synced_at = now() - interval '60 days' WHERE created_by = $1`, [ids.lhwB]);
      await query(`ALTER TABLE ${table} ENABLE TRIGGER ${table}_server_seq`);
    }
    await query('UPDATE devices SET last_sync_at = NULL WHERE user_id = $1', [ids.lhwB]);
    const lhwB = async () => (await get(admin, `/dashboard/lhw-activity?lhwId=${ids.lhwB}`)).body.lhws[0];
    const before = await lhwB();
    expect(Date.now() - new Date(before.lastSyncAt).getTime()).toBeGreaterThan(59 * 86400000);
    expect((await get(admin, '/dashboard/summary')).body).toMatchObject({ lhws: 2, lhwsSyncedToday: 1 });

    const pull = await request(app).get('/api/v1/sync/pull?since=0')
      .set('Authorization', `Bearer ${tokenFor(ids.lhwB, 'lhw', ids.deviceB)}`);

    expect(pull.status).toBe(200);
    expect(Date.now() - new Date((await lhwB()).lastSyncAt).getTime()).toBeLessThan(60000);
    expect((await get(admin, '/dashboard/summary')).body).toMatchObject({ lhws: 2, lhwsSyncedToday: 2 });
  });
});
