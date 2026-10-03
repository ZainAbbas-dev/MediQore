const jwt = require('jsonwebtoken');
const request = require('supertest');
const { createApp } = require('../src/app');
const { describeDb, resetDatabase, createFixtures, tokenFor, closePool, query, PASSWORD } = require('./db');

describe('authenticate (no database needed)', () => {
  it('rejects a request without a token', async () => {
    const res = await request(createApp()).get('/api/v1/sync/pull');

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('rejects a token signed with another secret', async () => {
    const forged = jwt.sign({ role: 'admin' }, 'not-our-secret', { subject: '6f1c2b8e-4d3a-4f5b-9c7d-2e1a0b9c8d7e' });

    const res = await request(createApp()).get('/api/v1/households').set('Authorization', `Bearer ${forged}`);

    expect(res.status).toBe(401);
  });

  it('rejects an expired token', async () => {
    const expired = jwt.sign({ role: 'lhw' }, process.env.JWT_ACCESS_SECRET, {
      subject: '6f1c2b8e-4d3a-4f5b-9c7d-2e1a0b9c8d7e',
      expiresIn: -10,
    });

    const res = await request(createApp()).get('/api/v1/sync/pull').set('Authorization', `Bearer ${expired}`);

    expect(res.status).toBe(401);
  });
});

describeDb('POST /api/v1/auth/login', () => {
  let ids;
  const app = createApp();

  beforeAll(async () => {
    await resetDatabase();
    ids = await createFixtures();
  });

  afterAll(closePool);

  it('returns an access token for valid credentials and records the login', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({ username: 'Supervisor.A', password: PASSWORD });

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ tokenType: 'Bearer', user: { id: ids.supervisorA, role: 'supervisor' } });
    const payload = jwt.verify(res.body.accessToken, process.env.JWT_ACCESS_SECRET);
    expect(payload.sub).toBe(ids.supervisorA);

    const { rows: [user] } = await query('SELECT last_login_at FROM users WHERE id = $1', [ids.supervisorA]);
    expect(user.last_login_at).not.toBeNull();
    const { rows: audit } = await query(
      `SELECT details FROM audit_log WHERE action = 'login' AND user_id = $1`, [ids.supervisorA]);
    expect(audit.map((a) => a.details.result)).toContain('success');
  });

  it('refuses a wrong password and audits the failure', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({ username: 'lhw.a', password: 'wrong' });

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
    const { rows } = await query(
      `SELECT details FROM audit_log WHERE action = 'login' AND user_id = $1`, [ids.lhwA]);
    expect(rows.map((r) => r.details)).toContainEqual({ result: 'failed', reason: 'wrong_password' });
  });

  it('gives the same answer for an unknown username', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({ username: 'nobody', password: PASSWORD });

    expect(res.status).toBe(401);
    expect(res.body.error).toEqual({ code: 'INVALID_CREDENTIALS', message: 'Username or password is incorrect' });
  });

  it('refuses a deactivated account', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({ username: 'lhw.inactive', password: PASSWORD });

    expect(res.status).toBe(401);
  });

  it('validates the body', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({ username: 'lhw.a' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('refuses a valid token once the account is deactivated', async () => {
    const res = await request(app)
      .get('/api/v1/sync/pull')
      .set('Authorization', `Bearer ${tokenFor(ids.inactiveLhw, 'lhw')}`);

    expect(res.status).toBe(401);
  });
});
