// M1 FE-1, FE-3: admins create LHWs (LHW ID and credentials issued by the
// system), reassign their area, deactivate and reactivate them, and reset passwords.
const { randomUUID } = require('node:crypto');
const request = require('supertest');
const { createApp } = require('../src/app');
const { loginThrottle } = require('../src/services/login-throttle');
const { describeDb, resetDatabase, createFixtures, insertApprovedDevice, tokenFor, closePool, query } = require('./db');

const app = createApp();

describeDb('LHW accounts (admin)', () => {
  let ids;
  let admin;
  const as = (token) => ({
    get: (path) => request(app).get(`/api/v1${path}`).set('Authorization', `Bearer ${token}`),
    post: (path, body) => request(app).post(`/api/v1${path}`).set('Authorization', `Bearer ${token}`).send(body),
    patch: (path, body) => request(app).patch(`/api/v1${path}`).set('Authorization', `Bearer ${token}`).send(body),
  });

  beforeAll(async () => {
    await resetDatabase();
    ids = await createFixtures();
    admin = as(tokenFor(ids.admin, 'admin'));
  });

  beforeEach(() => loginThrottle.reset());

  afterAll(closePool);

  it('is for admins only', async () => {
    const supervisor = await as(tokenFor(ids.supervisorA, 'supervisor')).get('/admin/lhws');
    const lhw = await as(tokenFor(ids.lhwA, 'lhw', ids.deviceA)).get('/admin/areas');

    expect(supervisor.status).toBe(403);
    expect(lhw.status).toBe(403);
  });

  it('lists the areas with their Union Council, tehsil and district', async () => {
    const res = await admin.get('/admin/areas');

    expect(res.status).toBe(200);
    expect(res.body.areas).toContainEqual({ id: ids.areaA, name: 'Area A', unionCouncil: 'UC', tehsil: 'T', district: 'Area A District' });
  });

  describe('creating an LHW', () => {
    let created;

    it('issues the next LHW ID as the username and a one-time-shown password', async () => {
      const res = await admin.post('/admin/lhws', { fullName: 'Ayesha Test', areaId: ids.areaB, phone: '0300 1234567' });

      expect(res.status).toBe(201);
      created = res.body;
      expect(created.lhw).toMatchObject({
        lhwCode: 'LHW-00001',
        username: 'LHW-00001',
        fullName: 'Ayesha Test',
        phone: '0300 1234567',
        isActive: true,
        area: { id: ids.areaB, name: 'Area B', district: { name: 'Area B District' } },
        devices: { approved: 0, pending: 0 },
      });
      expect(created.credentials.username).toBe('LHW-00001');
      expect(created.credentials.password).toMatch(/^[A-HJ-NP-Za-hj-km-np-z2-9]{10}$/);
      const { rows: [user] } = await query('SELECT password_hash FROM users WHERE id = $1', [created.lhw.id]);
      expect(user.password_hash).not.toContain(created.credentials.password);
    });

    it('lets the new LHW sign in from the app, pending phone approval', async () => {
      const res = await request(app).post('/api/v1/auth/login').send({
        username: created.credentials.username, password: created.credentials.password, deviceId: randomUUID(),
      });

      expect(res.status).toBe(202);
    });

    it('gives each new LHW the next number and audits the creation', async () => {
      const res = await admin.post('/admin/lhws', { fullName: 'Fatima Test', areaId: ids.areaA });

      expect(res.body.lhw.lhwCode).toBe('LHW-00002');
      const { rows } = await query(`SELECT user_id, details FROM audit_log WHERE action = 'create' AND entity_type = 'users'`);
      expect(rows).toHaveLength(2);
      expect(rows[0]).toMatchObject({ user_id: ids.admin, details: { role: 'lhw', lhwCode: 'LHW-00001' } });
    });

    it.each([
      ['no name', { areaId: 'AREA' }, 'VALIDATION_ERROR'],
      ['an area that does not exist', { fullName: 'X Y', areaId: randomUUID() }, 'UNKNOWN_AREA'],
      ['a phone number with letters', { fullName: 'X Y', areaId: 'AREA', phone: 'call me' }, 'VALIDATION_ERROR'],
    ])('refuses %s', async (_, body, code) => {
      const res = await admin.post('/admin/lhws', { ...body, areaId: body.areaId === 'AREA' ? ids.areaA : body.areaId });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe(code);
    });

    it('lists LHWs with search and status filters', async () => {
      const all = await admin.get('/admin/lhws');
      const search = await admin.get('/admin/lhws?search=ayesha');
      const inArea = await admin.get(`/admin/lhws?areaId=${ids.areaA}`);

      expect(all.body.lhws.map((l) => l.lhwCode)).toEqual(['LHW-00001', 'LHW-00002', 'LHW-A', 'LHW-B']);
      expect(search.body.lhws.map((l) => l.lhwCode)).toEqual(['LHW-00001']);
      expect(inArea.body.lhws.map((l) => l.lhwCode)).toEqual(['LHW-00002', 'LHW-A']);
      expect(all.body.lhws.find((l) => l.lhwCode === 'LHW-A').devices).toEqual({ approved: 1, pending: 0 });
    });
  });

  it('reassigns the area, audits the change and scopes the next pull to the new area', async () => {
    const lhw = await insertLhwWithPhone('Area move', ids.areaA);

    const res = await admin.patch(`/admin/lhws/${lhw.id}`, { areaId: ids.areaB, fullName: 'Area Moved' });

    expect(res.status).toBe(200);
    expect(res.body.lhw).toMatchObject({ fullName: 'Area Moved', area: { id: ids.areaB } });
    const { rows: [audit] } = await query(
      `SELECT details FROM audit_log WHERE action = 'edit' AND entity_id = $1`, [lhw.id]);
    expect(audit.details.changes.areaId).toEqual({ from: ids.areaA, to: ids.areaB });

    const login = await request(app).post('/api/v1/auth/login').send({ username: lhw.username, password: lhw.password, deviceId: lhw.deviceId });
    expect(login.body.user.areaId).toBe(ids.areaB);
  });

  it('deactivates an LHW: refresh tokens revoked, next sync refused; reactivation lets them back', async () => {
    const lhw = await insertLhwWithPhone('Deactivate me', ids.areaA);
    const { body: session } = await request(app).post('/api/v1/auth/login')
      .send({ username: lhw.username, password: lhw.password, deviceId: lhw.deviceId });

    const off = await admin.post(`/admin/lhws/${lhw.id}/deactivate`);
    const sync = await request(app).get('/api/v1/sync/pull').set('Authorization', `Bearer ${session.accessToken}`);
    const refresh = await request(app).post('/api/v1/auth/refresh').send({ refreshToken: session.refreshToken });

    expect(off.body.lhw.isActive).toBe(false);
    expect(sync.status).toBe(403);
    expect(sync.body.error.code).toBe('ACCOUNT_INACTIVE');
    expect(refresh.status).toBe(401);

    const on = await admin.post(`/admin/lhws/${lhw.id}/activate`);
    const login = await request(app).post('/api/v1/auth/login')
      .send({ username: lhw.username, password: lhw.password, deviceId: lhw.deviceId });
    expect(on.body.lhw.isActive).toBe(true);
    expect(login.status).toBe(200);

    const { rows } = await query(
      `SELECT details->>'change' AS change FROM audit_log WHERE action = 'edit' AND entity_id = $1 ORDER BY id`, [lhw.id]);
    expect(rows.map((r) => r.change)).toEqual(['deactivate', 'activate']);
  });

  it('resets the password: the old one stops working, the new one works, sessions end', async () => {
    const lhw = await insertLhwWithPhone('Forgetful', ids.areaA);
    const { body: session } = await request(app).post('/api/v1/auth/login')
      .send({ username: lhw.username, password: lhw.password, deviceId: lhw.deviceId });

    const res = await admin.post(`/admin/lhws/${lhw.id}/reset-password`);

    expect(res.status).toBe(200);
    expect(res.body.credentials.username).toBe(lhw.username);
    const old = await request(app).post('/api/v1/auth/login').send({ username: lhw.username, password: lhw.password, deviceId: lhw.deviceId });
    const fresh = await request(app).post('/api/v1/auth/login')
      .send({ username: lhw.username, password: res.body.credentials.password, deviceId: lhw.deviceId });
    const refresh = await request(app).post('/api/v1/auth/refresh').send({ refreshToken: session.refreshToken });
    expect(old.status).toBe(401);
    expect(fresh.status).toBe(200);
    expect(refresh.status).toBe(401);
  });

  it('answers 404 for an unknown LHW', async () => {
    const res = await admin.post(`/admin/lhws/${randomUUID()}/deactivate`);

    expect(res.status).toBe(404);
  });

  // Creates an LHW through the API and approves a phone for them.
  async function insertLhwWithPhone(fullName, areaId) {
    const { body } = await admin.post('/admin/lhws', { fullName, areaId });
    const deviceId = await insertApprovedDevice(body.lhw.id);
    return { id: body.lhw.id, username: body.credentials.username, password: body.credentials.password, deviceId };
  }
});
