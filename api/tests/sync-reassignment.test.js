const { randomUUID } = require('node:crypto');
const request = require('supertest');
const { createApp } = require('../src/app');
const { describeDb, resetDatabase, createFixtures, insertArea, tokenFor, closePool, query } = require('./db');

const app = createApp();

function household(areaId, village = 'Old village') {
  return {
    table: 'households',
    id: randomUUID(),
    ...(areaId && { areaId }),
    createdOnDevice: '2026-10-01T09:30:00.000Z',
    data: { village },
  };
}

// M1 FE-3: after an admin moves an LHW to another area, records her phone made
// in the old area and syncs later keep the old area.
describeDb('sync after an area reassignment (M1 FE-3)', () => {
  let ids;
  let lhw;
  let admin;

  const push = (records) =>
    request(app).post('/api/v1/sync/push').set('Authorization', `Bearer ${lhw}`).send({ deviceId: ids.deviceA, records });
  const reassign = (areaId) =>
    request(app).patch(`/api/v1/admin/lhws/${ids.lhwA}`).set('Authorization', `Bearer ${admin}`).send({ areaId });
  const areaOf = async (id) => (await query('SELECT area_id FROM households WHERE id = $1', [id])).rows[0]?.area_id;

  beforeEach(async () => {
    await resetDatabase();
    ids = await createFixtures();
    lhw = tokenFor(ids.lhwA, 'lhw', ids.deviceA);
    admin = tokenFor(ids.admin, 'admin');
  });

  afterAll(closePool);

  it('files a record under the area the phone made it in', async () => {
    const record = household(ids.areaA);

    const res = await push([record]);

    expect(res.body.results[0].status).toBe('created');
    expect(await areaOf(record.id)).toBe(ids.areaA);
  });

  it('files a record without an area under the current area', async () => {
    const record = household();

    await push([record]);

    expect(await areaOf(record.id)).toBe(ids.areaA);
  });

  it('keeps the old area for records made before the reassignment and synced after it', async () => {
    const before = household(ids.areaA);
    await push([before]);
    expect((await reassign(ids.areaB)).status).toBe(200);

    const late = household(ids.areaA, 'Made offline before the move');
    const edit = { ...before, data: { village: 'Edited offline' } };
    const fresh = household(ids.areaB, 'New area village');
    const res = await push([late, edit, fresh]);

    expect(res.body.results.map((r) => r.status)).toEqual(['created', 'updated', 'created']);
    expect(await areaOf(late.id)).toBe(ids.areaA);
    expect(await areaOf(before.id)).toBe(ids.areaA);
    expect(await areaOf(fresh.id)).toBe(ids.areaB);
    const { rows: [audit] } = await query(
      `SELECT details FROM audit_log WHERE action = 'create' AND entity_id = $1`, [late.id]);
    expect(audit.details).toMatchObject({ areaId: ids.areaA, previousArea: true });
  });

  it('refuses an area the LHW was never assigned to', async () => {
    const record = household(ids.areaB);

    const res = await push([record]);

    expect(res.body.results[0]).toMatchObject({ status: 'rejected', reason: 'OUT_OF_AREA' });
    expect(await areaOf(record.id)).toBeUndefined();
  });

  it('keeps only the area before the latest reassignment', async () => {
    const areaC = await insertArea('Area C');
    await reassign(ids.areaB);
    await reassign(areaC);

    const res = await push([household(ids.areaA), household(ids.areaB), household(areaC)]);

    expect(res.body.results.map((r) => r.reason || r.status)).toEqual(['OUT_OF_AREA', 'created', 'created']);
  });

  it('pulls only the current area, and says which area each record is in', async () => {
    const old = household(ids.areaA);
    await push([old]);
    await reassign(ids.areaB);
    const fresh = household(ids.areaB, 'New area village');
    await push([fresh]);

    const res = await request(app).get('/api/v1/sync/pull').set('Authorization', `Bearer ${lhw}`);

    expect(res.body.records.map((r) => [r.id, r.areaId])).toEqual([[fresh.id, ids.areaB]]);
  });
});
