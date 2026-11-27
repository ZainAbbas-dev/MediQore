const request = require('supertest');
const { createApp } = require('../src/app');
const { describeDb, resetDatabase, createFixtures, tokenFor, closePool, query } = require('./db');

const app = createApp();
const contacts = '/area-config/escalation-contacts';
const campaigns = '/area-config/campaign-rounds';
const dates = { startsOn: '2090-03-04', endsOn: '2090-03-08' };
const contact = {
  supervisorPhone: '0000-0000001',
  secondaryName: 'Synthetic District Hospital',
  secondaryPhone: '0000-0000002',
};

function as(id, role, deviceId) {
  const token = tokenFor(id, role, deviceId);
  return (method, path, body) => {
    const call = request(app)[method](`/api/v1${path}`).set('Authorization', `Bearer ${token}`);
    return body === undefined ? call : call.send(body);
  };
}

describeDb('area administration (M10 FE-3)', () => {
  let ids;
  let admin;
  let supervisor;
  let phoneA;
  let phoneB;

  beforeEach(async () => {
    await resetDatabase();
    ids = await createFixtures();
    admin = as(ids.admin, 'admin');
    supervisor = as(ids.supervisorA, 'supervisor');
    phoneA = as(ids.lhwA, 'lhw', ids.deviceA);
    phoneB = as(ids.lhwB, 'lhw', ids.deviceB);
  });
  afterAll(closePool);

  async function grant(permission) {
    expect((await admin('put', '/admin/roles/permissions', { changes: [
      { role: 'supervisor', permission, granted: true },
    ] })).status).toBe(200);
  }

  it('publishes the saved contact only to its area and audits updates and removal', async () => {
    const path = `${contacts}/${ids.areaA}`;
    const saved = await admin('put', path, { ...contact, supervisorUserId: ids.supervisorA });
    expect(saved.status).toBe(201);
    expect(saved.body.contact).toMatchObject({ ...contact, supervisorUserId: ids.supervisorA, escalateAfterMinutes: 15 });
    expect((await admin('get', path)).body.contact).toEqual(saved.body.contact);

    const config = await phoneA('get', '/sync/config');
    expect(config.body.escalationContact).toMatchObject({ ...contact, escalateAfterMinutes: 15 });
    expect((await phoneB('get', '/sync/config')).body.escalationContact).toBeNull();

    const edit = await admin('put', path, { ...contact, escalateAfterMinutes: 20 });
    expect(edit.status).toBe(200);
    expect(edit.body.contact.id).toBe(saved.body.contact.id);
    expect((await phoneA('get', `/sync/config?have=${config.body.configVersion}`)).body.escalationContact.escalateAfterMinutes).toBe(20);
    expect((await admin('delete', path)).status).toBe(204);
    expect((await phoneA('get', '/sync/config')).body.escalationContact).toBeNull();

    const audit = await query(
      "SELECT action, user_id FROM audit_log WHERE entity_type = 'escalation_contacts' AND entity_id = $1 ORDER BY id",
      [saved.body.contact.id],
    );
    expect(audit.rows).toEqual(['create', 'edit', 'delete'].map((action) => ({ action, user_id: ids.admin })));
  });

  it('keeps contact scope and campaign permissions independent', async () => {
    expect((await supervisor('get', contacts)).status).toBe(403);
    expect((await phoneA('get', contacts)).status).toBe(403);
    await grant('escalation.manage');
    await admin('put', `${contacts}/${ids.areaB}`, contact);

    const options = await supervisor('get', `${contacts}/options`);
    expect(options.body.areas.map(({ id }) => id)).toEqual([ids.areaA]);
    expect(options.body.supervisors).toMatchObject([{ userId: ids.supervisorA, areaId: ids.areaA }]);
    expect((await supervisor('get', contacts)).body.contacts).toEqual([]);
    expect((await supervisor('get', `${contacts}/${ids.areaB}`)).status).toBe(404);
    expect((await supervisor('put', `${contacts}/${ids.areaB}`, contact)).status).toBe(403);
    expect((await supervisor('delete', `${contacts}/${ids.areaB}`)).status).toBe(404);
    expect((await supervisor('put', `${contacts}/${ids.areaA}`, contact)).status).toBe(201);
    expect((await supervisor('get', campaigns)).status).toBe(403);
  });

  it('validates escalation phone details, the timer and supervisor assignment', async () => {
    const path = `${contacts}/${ids.areaB}`;
    for (const invalid of [
      { supervisorPhone: '0000-invalid' },
      { secondaryPhone: null },
      { escalateAfterMinutes: 0 },
      { supervisorUserId: ids.supervisorA },
    ]) {
      expect((await admin('put', path, { ...contact, ...invalid })).status).toBe(400);
    }
    expect((await admin('get', contacts)).body.contacts).toEqual([]);
  });

  it('creates one round for two areas, syncs stable per-area campaign IDs, and audits the round', async () => {
    const created = await admin('post', campaigns, {
      name: 'Synthetic Spring Round', ...dates, areaIds: [ids.areaA, ids.areaB],
    });
    expect(created.status).toBe(201);
    const { round } = created.body;
    expect(round).toMatchObject({ name: 'Synthetic Spring Round', ...dates, editable: true });
    expect(round.areas.map(({ id }) => id)).toEqual([ids.areaA, ids.areaB]);
    expect((await admin('get', campaigns)).body.rounds).toEqual([round]);

    const [campaignA] = (await phoneA('get', '/sync/config')).body.campaigns;
    const [campaignB] = (await phoneB('get', '/sync/config')).body.campaigns;
    expect(campaignA).toMatchObject({ name: round.name, ...dates });
    expect(campaignB).toMatchObject({ name: round.name, ...dates });
    expect(campaignA.id).not.toBe(campaignB.id);

    const path = `${campaigns}/${round.id}`;
    expect((await admin('patch', path, { name: 'Synthetic Updated Round', areaIds: [ids.areaA] })).status).toBe(200);
    expect((await phoneA('get', '/sync/config')).body.campaigns).toEqual([
      { id: campaignA.id, name: 'Synthetic Updated Round', ...dates },
    ]);
    expect((await phoneB('get', '/sync/config')).body.campaigns).toEqual([]);
    expect((await admin('patch', path, { areaIds: [ids.areaA, ids.areaB] })).status).toBe(200);
    expect((await phoneB('get', '/sync/config')).body.campaigns[0].id).toBe(campaignB.id);

    expect((await admin('delete', path)).status).toBe(204);
    expect((await admin('get', campaigns)).body.rounds).toEqual([]);
    expect((await phoneA('get', '/sync/config')).body.campaigns).toEqual([]);
    const audit = await query(
      "SELECT action, user_id FROM audit_log WHERE entity_type = 'campaigns' AND entity_id = $1 ORDER BY id",
      [round.id],
    );
    expect(audit.rows).toEqual(['create', 'edit', 'edit', 'delete'].map((action) => ({ action, user_id: ids.admin })));
  });

  it('shows supervisors only their campaign areas and prevents edits to shared rounds', async () => {
    await grant('campaigns.manage');
    const values = { name: 'Synthetic Shared Round', ...dates };
    const { body } = await admin('post', campaigns, { ...values, areaIds: [ids.areaA, ids.areaB] });
    expect((await supervisor('post', campaigns, { ...values, areaIds: [ids.areaA, ids.areaB] })).status).toBe(403);
    const options = await supervisor('get', `${campaigns}/options`);
    expect(options.body.areas.map(({ id }) => id)).toEqual([ids.areaA]);
    const { rounds: [visible] } = (await supervisor('get', campaigns)).body;
    expect(visible.editable).toBe(false);
    expect(visible.areas.map(({ id }) => id)).toEqual([ids.areaA]);
    expect((await supervisor('patch', `${campaigns}/${body.round.id}`, { name: 'Edited' })).status).toBe(403);
    expect((await supervisor('delete', `${campaigns}/${body.round.id}`)).status).toBe(403);
    expect((await supervisor('post', campaigns, { ...values, areaIds: [ids.areaA] })).status).toBe(201);
  });

  it('rejects invalid dates and areas without storing a partial campaign', async () => {
    const values = { name: 'Synthetic Invalid Round', ...dates, areaIds: [ids.areaA] };
    for (const invalid of [
      { startsOn: '2090-02-30' },
      { endsOn: '2090-03-01' },
      { areaIds: [] },
      { areaIds: [ids.areaA, ids.areaA] },
      { areaIds: [ids.areaA.replaceAll('-', ':')] },
      { areaIds: [ids.areaA, '00000000-0000-4000-8000-000000000000'] },
    ]) {
      expect((await admin('post', campaigns, { ...values, ...invalid })).status).toBe(400);
    }
    expect((await query('SELECT id FROM campaigns')).rowCount).toBe(0);
  });

  it('preserves the areas and dates of recorded field visits', async () => {
    const created = await admin('post', campaigns, {
      name: 'Synthetic Field Round', ...dates, areaIds: [ids.areaA, ids.areaB],
    });
    const path = `${campaigns}/${created.body.round.id}`;
    const { rows: [home] } = await query(
      'INSERT INTO households (area_id, created_by) VALUES ($1, $2) RETURNING id', [ids.areaB, ids.lhwB],
    );
    await query(
      `INSERT INTO campaign_household_status (
         area_id, created_by, campaign_id, household_id, visited_on, status, children_under_5, children_vaccinated
       )
       SELECT $1, $2, id, $3, '2090-03-05', 'all_vaccinated', 1, 1
       FROM campaigns WHERE round_id = $4 AND area_id = $1`,
      [ids.areaB, ids.lhwB, home.id, created.body.round.id],
    );

    expect((await admin('delete', path)).status).toBe(409);
    expect((await admin('patch', path, { areaIds: [ids.areaA] })).status).toBe(409);
    expect((await admin('patch', path, { startsOn: '2090-03-06' })).status).toBe(409);
    expect((await admin('patch', path, { startsOn: '2090-03-05', areaIds: [ids.areaB] })).status).toBe(200);
    const { rounds: [round] } = (await admin('get', campaigns)).body;
    expect(round.startsOn).toBe('2090-03-05');
    expect(round.areas.map(({ id }) => id)).toEqual([ids.areaB]);
  });
});
