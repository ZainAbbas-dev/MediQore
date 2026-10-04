// M1 FE-2: sign-in from the app with phone approval by one-time code
// (decision 0002), refresh tokens, sign-out and login rate limiting.
const { randomUUID } = require('node:crypto');
const request = require('supertest');
const { createApp } = require('../src/app');
const { loginThrottle } = require('../src/services/login-throttle');
const { describeDb, resetDatabase, createFixtures, tokenFor, closePool, query, PASSWORD } = require('./db');

const app = createApp();

describeDb('sign-in from the app (M1 FE-2)', () => {
  let ids;

  const login = (body) => request(app).post('/api/v1/auth/login').send(body);
  const verify = (body) => request(app).post('/api/v1/auth/otp/verify').send(body);
  const issueCode = (token, deviceId) =>
    request(app).post(`/api/v1/devices/${deviceId}/code`).set('Authorization', `Bearer ${token}`);
  const pending = (token) => request(app).get('/api/v1/devices/pending').set('Authorization', `Bearer ${token}`);

  beforeAll(async () => {
    await resetDatabase();
    ids = await createFixtures();
  });

  beforeEach(() => loginThrottle.reset());

  afterAll(closePool);

  it('requires LHWs to sign in with a phone', async () => {
    const res = await login({ username: 'lhw.a', password: PASSWORD });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('DEVICE_REQUIRED');
  });

  it('signs in at once from an approved phone, with access and refresh tokens and the LHW profile', async () => {
    const res = await login({ username: 'lhw.a', password: PASSWORD, deviceId: ids.deviceA });

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      status: 'ok',
      tokenType: 'Bearer',
      user: { id: ids.lhwA, role: 'lhw', lhwCode: 'LHW-A', areaId: ids.areaA, areaName: 'Area A' },
    });
    expect(res.body.refreshToken).toEqual(expect.any(String));
    expect(new Date(res.body.refreshExpiresAt).getTime()).toBeGreaterThan(Date.now());
  });

  describe('a new phone', () => {
    const phone = randomUUID();
    let code;

    it('is registered as pending and asks for a one-time code', async () => {
      const res = await login({ username: 'lhw.a', password: PASSWORD, deviceId: phone, deviceModel: 'Test phone' });

      expect(res.status).toBe(202);
      expect(res.body).toEqual({ status: 'otp_required', otp: { channel: 'admin_issued' } });
      const { rows: [device] } = await query('SELECT user_id, model, verified_at FROM devices WHERE id = $1', [phone]);
      expect(device).toEqual({ user_id: ids.lhwA, model: 'Test phone', verified_at: null });
    });

    it('cannot sync while pending, even with a token naming it', async () => {
      const pull = await request(app)
        .get('/api/v1/sync/pull')
        .set('Authorization', `Bearer ${tokenFor(ids.lhwA, 'lhw', phone)}`);
      expect(pull.status).toBe(403);
      expect(pull.body.error.code).toBe('DEVICE_NOT_ALLOWED');
      const push = await request(app)
        .post('/api/v1/sync/push')
        .set('Authorization', `Bearer ${tokenFor(ids.lhwA, 'lhw', phone)}`)
        .send({ deviceId: phone, records: [{ table: 'households', id: randomUUID(), createdOnDevice: new Date().toISOString(), data: { village: 'X' } }] });
      expect(push.status).toBe(403);
    });

    it('shows on the pending list of the admin and of the supervisor of that area only', async () => {
      const admin = await pending(tokenFor(ids.admin, 'admin'));
      expect(admin.body.devices.map((d) => d.id)).toContain(phone);
      const [device] = admin.body.devices.filter((d) => d.id === phone);
      expect(device).toMatchObject({ model: 'Test phone', codeExpiresAt: null, user: { lhwCode: 'LHW-A', areaName: 'Area A' } });

      const supervisor = await pending(tokenFor(ids.supervisorA, 'supervisor'));
      expect(supervisor.body.devices.map((d) => d.id)).toContain(phone);

      const lhw = await pending(tokenFor(ids.lhwA, 'lhw', ids.deviceA));
      expect(lhw.status).toBe(403);
    });

    it('gets a 6-digit code from the supervisor, shown once and stored only as a hash', async () => {
      const res = await issueCode(tokenFor(ids.supervisorA, 'supervisor'), phone);

      expect(res.status).toBe(201);
      expect(res.body.code).toMatch(/^\d{6}$/);
      expect(res.body.purpose).toBe('new_device'); // LHW A already has an approved phone
      code = res.body.code;
      const { rows } = await query('SELECT code_hash, channel FROM otp_codes WHERE device_id = $1', [phone]);
      expect(rows).toHaveLength(1);
      expect(rows[0].code_hash).not.toContain(code);
      expect(rows[0].channel).toBe('admin_issued');
      const { rows: audit } = await query(
        `SELECT user_id, details FROM audit_log WHERE action = 'create' AND entity_type = 'otp_codes'`);
      expect(audit).toEqual([{ user_id: ids.supervisorA, details: expect.objectContaining({ deviceId: phone, forUser: ids.lhwA }) }]);
      expect(JSON.stringify(audit)).not.toContain(code);
    });

    it('refuses a wrong code and counts the attempt', async () => {
      const wrong = code === '000000' ? '111111' : '000000';
      const res = await verify({ username: 'lhw.a', password: PASSWORD, deviceId: phone, code: wrong });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('OTP_INVALID');
      const { rows: [row] } = await query('SELECT attempts FROM otp_codes WHERE device_id = $1', [phone]);
      expect(row.attempts).toBe(1);
    });

    it('is approved by the right code, which then signs in', async () => {
      const res = await verify({ username: 'lhw.a', password: PASSWORD, deviceId: phone, code });

      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({ status: 'ok', user: { id: ids.lhwA } });
      const { rows: [device] } = await query('SELECT verified_at FROM devices WHERE id = $1', [phone]);
      expect(device.verified_at).not.toBeNull();
      const { rows: audit } = await query(
        `SELECT details FROM audit_log WHERE action = 'login' AND device_id = $1 ORDER BY id`, [phone]);
      expect(audit.map((a) => a.details.result)).toEqual(['otp_required', 'failed', 'device_verified']);
    });

    it('signs in directly from then on, and the used code cannot be reused', async () => {
      const res = await login({ username: 'lhw.a', password: PASSWORD, deviceId: phone });
      expect(res.status).toBe(200);
      const { rows: [row] } = await query('SELECT consumed_at FROM otp_codes WHERE device_id = $1', [phone]);
      expect(row.consumed_at).not.toBeNull();
    });
  });

  it('voids a code after five wrong tries', async () => {
    const phone = randomUUID();
    await login({ username: 'lhw.b', password: PASSWORD, deviceId: phone });
    const { body } = await issueCode(tokenFor(ids.admin, 'admin'), phone);
    const wrong = body.code === '000000' ? '111111' : '000000';

    const codes = [];
    for (let i = 0; i < 5; i += 1) {
      loginThrottle.reset(); // this test is about the code's own limit
      codes.push((await verify({ username: 'lhw.b', password: PASSWORD, deviceId: phone, code: wrong })).body.error.code);
    }
    loginThrottle.reset();
    const after = await verify({ username: 'lhw.b', password: PASSWORD, deviceId: phone, code: body.code });

    expect(codes).toEqual(['OTP_INVALID', 'OTP_INVALID', 'OTP_INVALID', 'OTP_INVALID', 'OTP_LOCKED']);
    expect(after.body.error.code).toBe('OTP_NOT_ISSUED');
  });

  it('does not let a supervisor issue codes outside their areas', async () => {
    const phone = randomUUID();
    await login({ username: 'lhw.b', password: PASSWORD, deviceId: phone });

    const list = await pending(tokenFor(ids.supervisorA, 'supervisor'));
    const res = await issueCode(tokenFor(ids.supervisorA, 'supervisor'), phone);

    expect(list.body.devices.map((d) => d.id)).not.toContain(phone);
    expect(res.status).toBe(404);
  });

  it('refuses a phone that belongs to another account', async () => {
    const res = await login({ username: 'lhw.b', password: PASSWORD, deviceId: ids.deviceA });

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('DEVICE_NOT_ALLOWED');
  });

  describe('refresh and sign-out', () => {
    it('swaps a refresh token for a new pair, once', async () => {
      const { body: first } = await login({ username: 'lhw.a', password: PASSWORD, deviceId: ids.deviceA });

      const refreshed = await request(app).post('/api/v1/auth/refresh').send({ refreshToken: first.refreshToken });
      const again = await request(app).post('/api/v1/auth/refresh').send({ refreshToken: first.refreshToken });

      expect(refreshed.status).toBe(200);
      expect(refreshed.body.refreshToken).not.toBe(first.refreshToken);
      expect(refreshed.body.user.areaId).toBe(ids.areaA);
      expect(again.status).toBe(401);
      expect(again.body.error.code).toBe('INVALID_REFRESH_TOKEN');
    });

    it('revokes the refresh token on sign-out', async () => {
      const { body } = await login({ username: 'supervisor.a', password: PASSWORD });

      const out = await request(app).post('/api/v1/auth/logout').send({ refreshToken: body.refreshToken });
      const res = await request(app).post('/api/v1/auth/refresh').send({ refreshToken: body.refreshToken });

      expect(out.status).toBe(204);
      expect(res.status).toBe(401);
      const { rows } = await query(
        `SELECT 1 FROM audit_log WHERE action = 'login' AND user_id = $1 AND details->>'result' = 'logout'`, [ids.supervisorA]);
      expect(rows).toHaveLength(1);
    });
  });

  describe('login rate limiting', () => {
    it('blocks a username from one address after five wrong passwords, even with the right one', async () => {
      for (let i = 0; i < 5; i += 1) {
        expect((await login({ username: 'supervisor.a', password: 'wrong' })).status).toBe(401);
      }

      const blocked = await login({ username: 'supervisor.a', password: PASSWORD });
      const other = await login({ username: 'admin', password: PASSWORD });

      expect(blocked.status).toBe(429);
      expect(blocked.body.error.code).toBe('TOO_MANY_ATTEMPTS');
      expect(Number(blocked.headers['retry-after'])).toBeGreaterThan(0);
      expect(other.status).toBe(200);
    });

    it('clears the count after a successful sign-in', async () => {
      for (let i = 0; i < 4; i += 1) await login({ username: 'supervisor.a', password: 'wrong' });
      expect((await login({ username: 'supervisor.a', password: PASSWORD })).status).toBe(200);
      for (let i = 0; i < 4; i += 1) await login({ username: 'supervisor.a', password: 'wrong' });

      expect((await login({ username: 'supervisor.a', password: PASSWORD })).status).toBe(200);
    });
  });
});
