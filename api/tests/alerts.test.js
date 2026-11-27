const request = require('supertest');
const { createApp } = require('../src/app');
const { processAlertPush } = require('../src/services/alerts-push.service');
const { describeDb, resetDatabase, createFixtures, insertUser, tokenFor, closePool, query } = require('./db');

const app = createApp();

async function patient(area, actor, code) {
  const { rows: [row] } = await query(
    `WITH household AS (
       INSERT INTO households (area_id, created_by) VALUES ($1, $2) RETURNING id
     ), woman AS (
       INSERT INTO women (area_id, created_by, household_id, patient_code, name)
       SELECT $1, $2, id, $3, 'Synthetic woman' FROM household RETURNING id
     )
     INSERT INTO pregnancies (area_id, created_by, woman_id, registered_on, pregnancy_month_at_registration,
       estimated_delivery_date, edd_basis)
     SELECT $1, $2, id, '2026-10-01', 3, '2027-04-01', 'month' FROM woman RETURNING id`,
    [area, actor, code],
  );
  return row.id;
}

async function emergency(area, actor, pregnancy, { owner = 'server', minutesAgo = 2, assessmentId = null } = {}) {
  const { rows: [row] } = await query(
    `INSERT INTO emergency_alerts (area_id, created_by, pregnancy_id, visit_recorded_at, raised_at, owner, server_owned_at, risk_assessment_id)
     VALUES ($1, $2, $3, now() - make_interval(mins => $4), now() - make_interval(mins => $4),
             $5, CASE WHEN $5 = 'server' THEN now() - make_interval(mins => $4) END, $6)
     RETURNING id`,
    [area, actor, pregnancy, minutesAgo, owner, assessmentId],
  );
  return row.id;
}

async function risk(area, actor, pregnancy, { emergency = false } = {}) {
  const { rows: [row] } = await query(
    `WITH visit AS (
       INSERT INTO visits (area_id, created_by, pregnancy_id, visited_at) VALUES ($1, $2, $3, now()) RETURNING id
     )
     INSERT INTO risk_assessments (area_id, created_by, pregnancy_id, visit_id, model_level, model_version,
       input_set, rule_result, rules_version, final_level, is_emergency)
     SELECT $1, $2, $3, id, 'high', 'test', 'five_feature', $4, 'test', 'red', $5 FROM visit RETURNING id`,
    [area, actor, pregnancy, emergency ? 'emergency' : 'none', emergency],
  );
  return row.id;
}

describeDb('M10 portal alerts', () => {
  let ids;
  let pregnancyA;
  let pregnancyB;
  let supervisor;
  let admin;
  const api = (method, path, token = supervisor) =>
    request(app)[method](`/api/v1/alerts${path}`).set('Authorization', `Bearer ${token}`);

  beforeEach(async () => {
    await resetDatabase();
    ids = await createFixtures();
    supervisor = tokenFor(ids.supervisorA, 'supervisor');
    admin = tokenFor(ids.admin, 'admin');
    pregnancyA = await patient(ids.areaA, ids.lhwA, 'LHW-A-001');
    pregnancyB = await patient(ids.areaB, ids.lhwB, 'LHW-B-001');
  });

  afterAll(closePool);

  it('shows emergency history and model-only Red across scoped, stable pages', async () => {
    const alertA = await emergency(ids.areaA, ids.lhwA, pregnancyA, { owner: 'phone' });
    await query(
      `INSERT INTO alert_attempts (area_id, created_by, alert_id, channel, recipient, status, attempted_at)
       VALUES ($1, $2, $3, 'sms', 'secondary', 'sent', now())`,
      [ids.areaA, ids.lhwA, alertA],
    );
    const redA = await risk(ids.areaA, ids.lhwA, pregnancyA);
    await risk(ids.areaA, ids.lhwA, pregnancyA, { emergency: true });
    const alertB = await emergency(ids.areaB, ids.lhwB, pregnancyB);

    const first = await api('get', '?limit=1');
    expect(first.status).toBe(200);
    expect(first.headers['cache-control']).toBe('private, no-store');
    expect(first.body).toMatchObject({ alerts: [{ id: redA, type: 'model_red', status: null }] });
    const second = await api('get', `?before=${first.body.nextBefore}&limit=1`);
    expect(second.body).toMatchObject({
      alerts: [{ id: alertA, type: 'emergency', patient: { patientCode: 'LHW-A-001' },
        attempts: [{ channel: 'sms', recipient: 'secondary', status: 'sent' }] }],
      nextBefore: null,
    });
    expect((await api('get', '', admin)).body.alerts.map((alert) => alert.id)).toEqual([alertB, redA, alertA]);
    expect((await api('get', '', tokenFor(ids.lhwA, 'lhw', ids.deviceA))).status).toBe(403);
  });

  it('acknowledges within assigned areas once even when requests overlap', async () => {
    const alertA = await emergency(ids.areaA, ids.lhwA, pregnancyA);
    const alertB = await emergency(ids.areaB, ids.lhwB, pregnancyB);
    expect((await api('post', `/${alertB}/acknowledge`)).status).toBe(404);
    expect((await api('post', `/${alertA}/acknowledge`, admin)).status).toBe(403);

    const responses = await Promise.all([
      api('post', `/${alertA}/acknowledge`),
      api('post', `/${alertA}/acknowledge`),
    ]);
    for (const response of responses) {
      expect(response.status).toBe(200);
      expect(response.body.alert).toMatchObject({ id: alertA, status: 'acknowledged', acknowledgement: { method: 'dashboard' } });
    }
    expect(responses[0].body.alert.acknowledgement).toEqual(responses[1].body.alert.acknowledgement);
    expect((await query('SELECT method FROM alert_acknowledgements WHERE alert_id = $1', [alertA])).rows)
      .toEqual([{ method: 'dashboard' }]);
    expect((await query('SELECT status, version FROM emergency_alerts WHERE id = $1', [alertA])).rows)
      .toEqual([{ status: 'acknowledged', version: 2 }]);
    expect((await query("SELECT action FROM audit_log WHERE entity_id = $1 AND action = 'alert'", [alertA])).rows)
      .toEqual([{ action: 'alert' }]);
  });

  it('shows the recorded danger sign and LHW in the filtered dashboard alert list', async () => {
    const assessmentId = await risk(ids.areaA, ids.lhwA, pregnancyA, { emergency: true });
    await query("UPDATE risk_assessments SET triggered_rules = '[\"vaginal_bleeding\"]' WHERE id = $1", [assessmentId]);
    const id = await emergency(ids.areaA, ids.lhwA, pregnancyA, { assessmentId });
    await risk(ids.areaA, ids.lhwA, pregnancyA);

    const response = await api('get', `?emergencyOnly=true&lhwId=${ids.lhwA}&days=7`);
    expect(response.status).toBe(200);
    expect(response.body.alerts).toMatchObject([{
      id, lhw: { name: expect.any(String), code: expect.any(String) },
      triggeringSigns: ['vaginal_bleeding'],
    }]);
    expect((await api('get', `?emergencyOnly=true&lhwId=${ids.lhwB}`)).body.alerts).toEqual([]);
  });

  it('uses the configured area escalation time for the display and the push reminder', async () => {
    await query(
      'INSERT INTO escalation_contacts (area_id, created_by, supervisor_phone, escalate_after_minutes) VALUES ($1, $2, $3, 5)',
      [ids.areaA, ids.admin, '03001234567'],
    );
    const waiting = await emergency(ids.areaA, ids.lhwA, pregnancyA, { minutesAgo: 6 });
    const fallback = await emergency(ids.areaB, ids.lhwB, pregnancyB, { minutesAgo: 6 });
    await processAlertPush({ send: async () => {} });
    const { body } = await api('get', '', admin);
    expect(body.alerts.find(({ id }) => id === waiting)).toMatchObject({ overdue: true, reminder: { status: 'no_subscribers' } });
    expect(body.alerts.find(({ id }) => id === fallback)).toMatchObject({ overdue: false, reminder: null });
  });

  it('keeps push subscriptions scoped to their supervisor and reports missing configuration', async () => {
    const names = ['FIREBASE_PROJECT_ID', 'FIREBASE_CLIENT_EMAIL', 'FIREBASE_PRIVATE_KEY'];
    const original = Object.fromEntries(names.map((name) => [name, process.env[name]]));
    try {
      names.forEach((name) => { delete process.env[name]; });
      const absent = await api('post', '/push/subscriptions').send({ token: 'browser-a' });
      expect(absent.status).toBe(503);
      expect(absent.body.error.code).toBe('PUSH_NOT_CONFIGURED');
      expect((await api('get', '')).body.pushAvailable).toBe(false);

      names.forEach((name) => { process.env[name] = 'mock-configuration'; });
      const first = await api('post', '/push/subscriptions').send({ token: 'browser-a' });
      const same = await api('post', '/push/subscriptions').send({ token: 'browser-a' });
      expect(first.status).toBe(200);
      expect(same.body).toEqual(first.body);
      expect((await api('get', '')).body.pushAvailable).toBe(true);
      expect((await api('post', '/push/subscriptions', admin).send({ token: 'browser-a' })).status).toBe(403);
      const supervisorB = await insertUser('supervisor.b', 'supervisor');
      const path = `/push/subscriptions/${first.body.id}`;
      expect((await api('delete', path, tokenFor(supervisorB, 'supervisor'))).status).toBe(204);
      expect((await query('SELECT user_id FROM alert_push_subscriptions WHERE id = $1', [first.body.id])).rows)
        .toEqual([{ user_id: ids.supervisorA }]);
      expect((await api('delete', path)).status).toBe(204);
      expect((await query('SELECT 1 FROM alert_push_subscriptions WHERE id = $1', [first.body.id])).rows).toEqual([]);
    } finally {
      for (const [name, value] of Object.entries(original)) {
        if (value === undefined) delete process.env[name];
        else process.env[name] = value;
      }
    }
  });

  it('routes push only to active supervisors with matching area assignments and resends once', async () => {
    const supervisorB = await insertUser('supervisor.b', 'supervisor');
    const inactive = await insertUser('supervisor.inactive', 'supervisor', { isActive: false });
    await query(
      'INSERT INTO supervisor_areas (supervisor_id, area_id) VALUES ($1, $2), ($3, $4)',
      [supervisorB, ids.areaB, inactive, ids.areaA],
    );
    await query(
      'INSERT INTO alert_push_subscriptions (user_id, token) VALUES ($1, $2), ($3, $4), ($5, $6)',
      [ids.supervisorA, 'browser-a', supervisorB, 'browser-b', inactive, 'disabled'],
    );
    const waiting = await emergency(ids.areaA, ids.lhwA, pregnancyA, { minutesAgo: 16 });
    const reached = await emergency(ids.areaA, ids.lhwA, pregnancyA, { minutesAgo: 16 });
    await query(
      `INSERT INTO alert_acknowledgements (area_id, created_by, alert_id, method, acknowledged_at)
       VALUES ($1, $2, $3, 'supervisor_reached', now())`,
      [ids.areaA, ids.lhwA, reached],
    );
    await emergency(ids.areaA, ids.lhwA, pregnancyA, { minutesAgo: 16, owner: 'phone' });
    await emergency(ids.areaB, ids.lhwB, pregnancyB);
    await risk(ids.areaA, ids.lhwA, pregnancyA);
    await risk(ids.areaA, ids.lhwA, pregnancyA, { emergency: true });
    const messages = [];
    const send = async (token, payload) => { messages.push({ token, payload }); };
    await Promise.all([processAlertPush({ send }), processAlertPush({ send })]);
    await processAlertPush({ send });
    expect(messages.map(({ token, payload }) => [token, payload.title]).sort()).toEqual([
      ['browser-a', 'Emergency alert'],
      ['browser-a', 'Emergency alert still unacknowledged'],
      ['browser-a', 'High-risk case'],
      ['browser-b', 'Emergency alert'],
    ]);
    expect(messages.every(({ payload }) => payload.url === '/alerts')).toBe(true);
    expect(JSON.stringify(messages)).not.toMatch(/LHW-A-001|LHW-B-001|Synthetic woman/);
    const { body } = await api('get', '');
    expect(body.alerts.find((alert) => alert.id === waiting).reminder).toMatchObject({ status: 'sent' });
    expect(body.alerts.find((alert) => alert.id === reached)).toMatchObject({
      status: 'acknowledged', acknowledgement: { method: 'supervisor_reached' }, reminder: null,
    });
  });
});
