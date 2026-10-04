const { randomUUID } = require('node:crypto');
const request = require('supertest');
const { createApp } = require('../src/app');
const { describeDb, resetDatabase, createFixtures, tokenFor, closePool } = require('./db');

const app = createApp();

describeDb('GET /api/v1/households', () => {
  let ids;

  beforeAll(async () => {
    await resetDatabase();
    ids = await createFixtures();
    const pushOne = (userId, deviceId, village) =>
      request(app)
        .post('/api/v1/sync/push')
        .set('Authorization', `Bearer ${tokenFor(userId, 'lhw', deviceId)}`)
        .send({
          deviceId,
          records: [{
            table: 'households',
            id: randomUUID(),
            createdOnDevice: '2026-10-01T09:30:00.000Z',
            data: { village, latitude: 33.6844, longitude: 73.0479 },
          }],
        });
    await pushOne(ids.lhwA, ids.deviceA, 'Village A');
    await pushOne(ids.lhwB, ids.deviceB, 'Village B');
  });

  afterAll(closePool);

  const list = (token) => request(app).get('/api/v1/households').set('Authorization', `Bearer ${token}`);

  it('shows a supervisor only the households in their areas', async () => {
    const res = await list(tokenFor(ids.supervisorA, 'supervisor'));

    expect(res.status).toBe(200);
    expect(res.body.households.map((h) => h.village)).toEqual(['Village A']);
    expect(res.body.households[0]).toMatchObject({ areaName: 'Area A', latitude: 33.6844, longitude: 73.0479 });
  });

  it('shows an admin every area', async () => {
    const res = await list(tokenFor(ids.admin, 'admin'));

    expect(res.body.households.map((h) => h.village).sort()).toEqual(['Village A', 'Village B']);
  });

  it('is not available to LHWs', async () => {
    const res = await list(tokenFor(ids.lhwA, 'lhw'));

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });
});
