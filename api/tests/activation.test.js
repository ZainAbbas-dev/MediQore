// M1 FE-2: activation of a phone with the admin's one-time code, sign-in
// again on an activated phone, the supervisor's PIN-reset reply code, refresh
// tokens, sign-out and login rate limiting.
const { randomUUID } = require('node:crypto');
const request = require('supertest');
const { createApp } = require('../src/app');
const { loginThrottle } = require('../src/services/login-throttle');
const activation = require('../src/services/activation.service');
const { describeDb, resetDatabase, createFixtures, tokenFor, closePool, query, PASSWORD } = require('./db');

const app = createApp();
// Shared test vector: the app's PIN-reset check must give the same reply code
// (mobile/test/auth/pin_reset_test.dart).
const VECTOR_REPLY = '26434093';

describeDb('sign-in from the app (M1 FE-2)', () => {
  let ids;

  const login = (body) => request(app).post('/api/v1/auth/login').send(body);
  const activate = (body) => request(app).post('/api/v1/auth/activate').send(body);
  const issueCode = (token, lhwId) =>
    request(app).post(`/api/v1/admin/lhws/${lhwId}/activation-code`).set('Authorization', `Bearer ${token}`);
  const replyCode = (token, body) =>
    request(app).post('/api/v1/pin-reset/reply-code').set('Authorization', `Bearer ${token}`).send(body);

  beforeAll(async () => {
    await resetDatabase();
    ids = await createFixtures();
    await query("UPDATE users SET phone = '0300 0000001' WHERE id = $1", [ids.supervisorA]);
    await query("INSERT INTO lhw_profiles (user_id, lhw_code, area_id) VALUES ($1, 'LHW-I', $2)", [ids.inactiveLhw, ids.areaA]);
  });

  beforeEach(() => loginThrottle.reset());

  afterAll(closePool);

  it('requires LHWs to sign in with a phone', async () => {
    const res = await login({ username: 'lhw.a', password: PASSWORD });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('DEVICE_REQUIRED');
  });

  it('signs in again with the password on an activated phone, with tokens, profile and the supervisor to call', async () => {
    const res = await login({ username: 'lhw.a', password: PASSWORD, deviceId: ids.deviceA });

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      status: 'ok',
      tokenType: 'Bearer',
      user: { id: ids.lhwA, role: 'lhw', lhwCode: 'LHW-A', areaId: ids.areaA, areaName: 'Area A' },
      supervisors: [{ name: 'Test supervisor.a', phone: '0300 0000001' }],
    });
    expect(res.body.refreshToken).toEqual(expect.any(String));
    expect(res.body.activationSecret).toBeUndefined();
    expect(new Date(res.body.refreshExpiresAt).getTime()).toBeGreaterThan(Date.now());
  });

  it('gives an LHW in an area without supervisors an empty contact list', async () => {
    const res = await login({ username: 'lhw.b', password: PASSWORD, deviceId: ids.deviceB });

    expect(res.body.supervisors).toEqual([]);
  });

  it('keeps the app for LHWs: a supervisor cannot sign in or activate with a phone', async () => {
    const signIn = await login({ username: 'supervisor.a', password: PASSWORD, deviceId: randomUUID() });
    const act = await activate({ username: 'supervisor.a', password: PASSWORD, activationCode: 'ABCD-EFGH', deviceId: randomUUID() });

    expect(signIn.status).toBe(403);
    expect(signIn.body.error.code).toBe('APP_FOR_LHWS');
    expect(act.body.error.code).toBe('APP_FOR_LHWS');
  });

  describe('activation codes', () => {
    it('are issued by an admin, shown once as XXXX-XXXX, valid 48 hours and stored only as a hash', async () => {
      const res = await issueCode(tokenFor(ids.admin, 'admin'), ids.lhwA);

      expect(res.status).toBe(201);
      expect(res.body.activationCode).toMatch(/^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$/);
      const hours = (new Date(res.body.expiresAt).getTime() - Date.now()) / 3_600_000;
      expect(hours).toBeGreaterThan(47.9);
      expect(hours).toBeLessThanOrEqual(48);
      expect(res.body.lhw.activationCodeExpiresAt).toBe(res.body.expiresAt);
      const { rows } = await query('SELECT code_hash, issued_by FROM activation_codes WHERE user_id = $1', [ids.lhwA]);
      expect(rows).toHaveLength(1);
      expect(rows[0].issued_by).toBe(ids.admin);
      expect(rows[0].code_hash).not.toContain(res.body.activationCode.replace('-', ''));
      const { rows: audit } = await query(
        `SELECT user_id, details FROM audit_log WHERE action = 'create' AND entity_type = 'activation_codes'`);
      expect(audit).toEqual([{ user_id: ids.admin, details: expect.objectContaining({ forUser: ids.lhwA }) }]);
      expect(JSON.stringify(audit)).not.toContain(res.body.activationCode.replace('-', ''));
    });

    it('cancel the earlier unused code when a new one is issued', async () => {
      const first = (await issueCode(tokenFor(ids.admin, 'admin'), ids.lhwB)).body.activationCode;
      const second = (await issueCode(tokenFor(ids.admin, 'admin'), ids.lhwB)).body.activationCode;
      const phone = randomUUID();

      const old = await activate({ username: 'lhw.b', password: PASSWORD, activationCode: first, deviceId: phone });
      expect(old.status).toBe(400);
      expect(old.body.error.code).toBe('ACTIVATION_CODE_INVALID');
      expect((await activate({ username: 'lhw.b', password: PASSWORD, activationCode: second, deviceId: phone })).status).toBe(200);
    });

    it('are for admins only, and only for active LHWs', async () => {
      const supervisor = await issueCode(tokenFor(ids.supervisorA, 'supervisor'), ids.lhwA);
      const inactive = await issueCode(tokenFor(ids.admin, 'admin'), ids.inactiveLhw);
      const unknown = await issueCode(tokenFor(ids.admin, 'admin'), randomUUID());

      expect(supervisor.status).toBe(403);
      expect(inactive.status).toBe(409);
      expect(unknown.status).toBe(404);
    });
  });

  describe('a new phone', () => {
    const phone = randomUUID();
    let code;
    let session;

    it('cannot sign in with the password alone', async () => {
      const res = await login({ username: 'lhw.a', password: PASSWORD, deviceId: phone });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('ACTIVATION_REQUIRED');
      const { rows } = await query('SELECT 1 FROM devices WHERE id = $1', [phone]);
      expect(rows).toHaveLength(0);
    });

    it('cannot sync before activation, even with a token naming it', async () => {
      const pull = await request(app)
        .get('/api/v1/sync/pull')
        .set('Authorization', `Bearer ${tokenFor(ids.lhwA, 'lhw', phone)}`);
      expect(pull.status).toBe(403);
      expect(pull.body.error.code).toBe('DEVICE_NOT_ALLOWED');
    });

    it('refuses a wrong activation code and counts it as a failed sign-in', async () => {
      code = (await issueCode(tokenFor(ids.admin, 'admin'), ids.lhwA)).body.activationCode;

      const res = await activate({ username: 'lhw.a', password: PASSWORD, activationCode: 'ZZZZ-ZZZZ', deviceId: phone });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('ACTIVATION_CODE_INVALID');
      const { rows: audit } = await query(
        `SELECT details FROM audit_log WHERE action = 'login' AND details->>'reason' = 'activation_code_invalid' AND details->>'deviceId' = $1`,
        [phone]);
      expect(audit).toHaveLength(1);
    });

    it('is activated by the right code, typed in lower case with a space, and gets its secret once', async () => {
      const typed = code.toLowerCase().replace('-', ' ');
      const res = await activate({ username: 'lhw.a', password: PASSWORD, activationCode: typed, deviceId: phone, deviceModel: 'Test phone' });

      expect(res.status).toBe(200);
      session = res.body;
      expect(session).toMatchObject({ status: 'ok', user: { id: ids.lhwA }, supervisors: [{ phone: '0300 0000001' }] });
      expect(Buffer.from(session.activationSecret, 'base64url')).toHaveLength(32);
      const { rows: [device] } = await query(
        'SELECT user_id, model, activated_at, activation_secret_ref FROM devices WHERE id = $1', [phone]);
      expect(device).toMatchObject({ user_id: ids.lhwA, model: 'Test phone' });
      expect(device.activated_at).not.toBeNull();
      expect(device.activation_secret_ref).not.toContain(session.activationSecret);
      const { rows: [used] } = await query(
        'SELECT consumed_at, device_id FROM activation_codes WHERE user_id = $1 AND consumed_at IS NOT NULL', [ids.lhwA]);
      expect(used.device_id).toBe(phone);
      const { rows: audit } = await query(
        `SELECT details FROM audit_log WHERE action = 'login' AND device_id = $1`, [phone]);
      expect(audit.map((a) => a.details.result)).toEqual(['activated']);
    });

    it('can sync and sign in again with the password from then on; the used code works only once', async () => {
      const pull = await request(app).get('/api/v1/sync/pull').set('Authorization', `Bearer ${session.accessToken}`);
      const again = await login({ username: 'lhw.a', password: PASSWORD, deviceId: phone });
      const reuse = await activate({ username: 'lhw.a', password: PASSWORD, activationCode: code, deviceId: randomUUID() });

      expect(pull.status).toBe(200);
      expect(again.status).toBe(200);
      expect(reuse.body.error.code).toBe('ACTIVATION_CODE_INVALID');
    });

    it("lets the area's supervisor give the reply code the phone expects for a forgotten PIN", async () => {
      const res = await replyCode(tokenFor(ids.supervisorA, 'supervisor'), { lhwId: ids.lhwA, challenge: '483 917' });

      expect(res.status).toBe(200);
      const secret = Buffer.from(session.activationSecret, 'base64url');
      expect(res.body.replyCode).toBe(activation.replyCode(secret, '483917'));
      expect(res.body.replyCode).toMatch(/^\d{8}$/);
      expect(res.body).toMatchObject({ lhw: { id: ids.lhwA, lhwCode: 'LHW-A' }, device: { model: 'Test phone' } });
      const { rows: audit } = await query(
        `SELECT user_id, details FROM audit_log WHERE entity_type = 'pin_reset_codes'`);
      expect(audit).toEqual([{ user_id: ids.supervisorA, details: { forUser: ids.lhwA, deviceId: phone } }]);
      expect(JSON.stringify(audit)).not.toContain(res.body.replyCode);
    });
  });

  describe('PIN-reset reply codes', () => {
    it('differ for each challenge', async () => {
      const a = await replyCode(tokenFor(ids.admin, 'admin'), { lhwId: ids.lhwA, challenge: '000001' });
      const b = await replyCode(tokenFor(ids.admin, 'admin'), { lhwId: ids.lhwA, challenge: '000002' });

      expect(a.body.replyCode).not.toBe(b.body.replyCode);
    });

    it('are refused outside the supervisor\'s areas, to LHWs, for a bad challenge and without an activated phone', async () => {
      const otherArea = await replyCode(tokenFor(ids.supervisorA, 'supervisor'), { lhwId: ids.lhwB, challenge: '123456' });
      const lhw = await replyCode(tokenFor(ids.lhwA, 'lhw', ids.deviceA), { lhwId: ids.lhwA, challenge: '123456' });
      const badChallenge = await replyCode(tokenFor(ids.admin, 'admin'), { lhwId: ids.lhwA, challenge: '12345' });
      await query("UPDATE devices SET revoked_at = now() WHERE user_id = $1", [ids.inactiveLhw]);
      const noPhone = await replyCode(tokenFor(ids.admin, 'admin'), { lhwId: ids.inactiveLhw, challenge: '123456' });

      expect(otherArea.status).toBe(404);
      expect(lhw.status).toBe(403);
      expect(badChallenge.status).toBe(400);
      expect(noPhone.status).toBe(404);
      expect(noPhone.body.error.code).toBe('NO_ACTIVATED_PHONE');
    });

    it('match the formula the app uses (shared test vector)', () => {
      const secret = Buffer.alloc(32, 7);
      expect(activation.replyCode(secret, '483917')).toBe(VECTOR_REPLY);
    });
  });

  it('refuses an expired activation code', async () => {
    const { body } = await issueCode(tokenFor(ids.admin, 'admin'), ids.lhwB);
    await query("UPDATE activation_codes SET created_at = now() - interval '49 hours', expires_at = now() - interval '1 hour' WHERE user_id = $1 AND consumed_at IS NULL AND revoked_at IS NULL", [ids.lhwB]);

    const res = await activate({ username: 'lhw.b', password: PASSWORD, activationCode: body.activationCode, deviceId: randomUUID() });

    expect(res.body.error.code).toBe('ACTIVATION_CODE_INVALID');
  });

  it('refuses a phone that belongs to another account', async () => {
    const signIn = await login({ username: 'lhw.b', password: PASSWORD, deviceId: ids.deviceA });
    const { body } = await issueCode(tokenFor(ids.admin, 'admin'), ids.lhwB);
    const act = await activate({ username: 'lhw.b', password: PASSWORD, activationCode: body.activationCode, deviceId: ids.deviceA });

    expect(signIn.status).toBe(403);
    expect(signIn.body.error.code).toBe('DEVICE_NOT_ALLOWED');
    expect(act.body.error.code).toBe('DEVICE_NOT_ALLOWED');
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
