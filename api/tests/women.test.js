const { randomUUID } = require('node:crypto');
const request = require('supertest');
const { createApp } = require('../src/app');
const { describeDb, resetDatabase, createFixtures, tokenFor, closePool, query, PASSWORD } = require('./db');

const app = createApp();

// One registration as the app sends it (M2 FE-1–3): household, woman,
// pregnancy and obstetric history, parents first.
function registration({ code = `LHW-A-${String(Math.floor(Math.random() * 1e4)).padStart(4, '0')}`, village = 'Dhok Syedan' } = {}) {
  const household = {
    table: 'households', id: randomUUID(), createdOnDevice: '2026-10-01T09:30:00.000Z',
    data: { village, address: 'House 12, Street 3', latitude: 33.6844, longitude: 73.0479 },
  };
  const woman = {
    table: 'women', id: randomUUID(), createdOnDevice: '2026-10-01T09:30:00.000Z',
    data: { householdId: household.id, patientCode: code, name: 'Synthetic Woman', age: 26, husbandName: 'Synthetic Husband', contactNumber: '0000-1234567' },
  };
  const pregnancy = {
    table: 'pregnancies', id: randomUUID(), createdOnDevice: '2026-10-01T09:30:00.000Z',
    data: { womanId: woman.id, registeredOn: '2026-10-01', pregnancyMonthAtRegistration: 3 },
  };
  const history = {
    table: 'obstetric_history', id: randomUUID(), createdOnDevice: '2026-10-01T09:30:00.000Z',
    data: { womanId: woman.id, previousPregnancies: 2, previousCSections: 1, stillbirths: 0, knownConditions: 'Asthma' },
  };
  return { household, woman, pregnancy, history, all: [household, woman, pregnancy, history] };
}

describeDb('Module 2: registration records through sync, and the portal list', () => {
  let ids;
  let lhwA;
  let lhwB;

  const push = (token, deviceId, records) =>
    request(app).post('/api/v1/sync/push').set('Authorization', `Bearer ${token}`).send({ deviceId, records });
  const pushA = (records) => push(lhwA, ids.deviceA, records);
  const statuses = (res) => res.body.results.map((r) => r.reason || r.status);
  const list = (token, query = '') => request(app).get(`/api/v1/women${query}`).set('Authorization', `Bearer ${token}`);

  beforeAll(async () => {
    await resetDatabase();
    ids = await createFixtures();
    lhwA = tokenFor(ids.lhwA, 'lhw', ids.deviceA);
    lhwB = tokenFor(ids.lhwB, 'lhw', ids.deviceB);
  });

  afterAll(closePool);

  describe('push (M2 FE-1, FE-2, FE-3)', () => {
    it('stores a whole registration in one batch, in the LHW area, with an audit row each', async () => {
      const reg = registration();

      const res = await pushA(reg.all);

      expect(res.status).toBe(200);
      expect(statuses(res)).toEqual(['created', 'created', 'created', 'created']);
      const { rows: [woman] } = await query('SELECT * FROM women WHERE id = $1', [reg.woman.id]);
      expect(woman).toMatchObject({ area_id: ids.areaA, created_by: ids.lhwA, household_id: reg.household.id, age: 26 });
      const { rows: [pregnancy] } = await query('SELECT * FROM pregnancies WHERE id = $1', [reg.pregnancy.id]);
      expect(pregnancy).toMatchObject({ registered_on: '2026-10-01', pregnancy_month_at_registration: 3, status: 'active' });
      const { rows: audit } = await query(
        `SELECT entity_type FROM audit_log WHERE action = 'create' AND entity_id = ANY($1) ORDER BY id`,
        [reg.all.map((r) => r.id)],
      );
      expect(audit.map((a) => a.entity_type)).toEqual(['households', 'women', 'pregnancies', 'obstetric_history']);
    });

    it('treats a resend of the registration as harmless', async () => {
      const reg = registration();
      await pushA(reg.all);

      const again = await pushA(reg.all);

      expect(statuses(again)).toEqual(['unchanged', 'unchanged', 'unchanged', 'unchanged']);
    });

    it('pulls the registration back with the same values', async () => {
      const { body: before } = await request(app).get('/api/v1/sync/pull').set('Authorization', `Bearer ${lhwA}`);
      const reg = registration();
      await pushA(reg.all);

      const res = await request(app).get(`/api/v1/sync/pull?since=${before.nextSince}`).set('Authorization', `Bearer ${lhwA}`);

      const byTable = Object.fromEntries(res.body.records.map((r) => [r.table, r]));
      expect(byTable.pregnancies.data).toEqual({ ...reg.pregnancy.data, status: 'active', closedOn: null });
      expect(byTable.obstetric_history.data).toEqual(reg.history.data);
      expect(byTable.women.data).toEqual(reg.woman.data);
      expect(byTable.women.areaId).toBe(ids.areaA);
    });

    it('refuses a woman whose household is not on the server, and still applies the rest of the batch', async () => {
      const orphan = registration();
      const other = registration();

      const res = await pushA([orphan.woman, ...other.all]);

      expect(statuses(res)).toEqual(['MISSING_PARENT', 'created', 'created', 'created', 'created']);
    });

    it("refuses a woman linked to another area's household", async () => {
      const inB = registration({ code: 'LHW-B-0001' });
      await push(lhwB, ids.deviceB, [inB.household]);
      const reg = registration();

      const res = await pushA([{ ...reg.woman, data: { ...reg.woman.data, householdId: inB.household.id } }]);

      expect(statuses(res)).toEqual(['OUT_OF_AREA']);
    });

    it('refuses a patient ID that is already used, without failing the batch', async () => {
      const first = registration({ code: 'LHW-A-0777' });
      await pushA(first.all);
      const second = registration({ code: 'LHW-A-0777' });

      const res = await pushA(second.all);

      expect(statuses(res)).toEqual(['created', 'DUPLICATE_PATIENT_ID', 'MISSING_PARENT', 'MISSING_PARENT']);
      const { rows } = await query('SELECT count(*)::int AS n FROM households WHERE id = $1', [second.household.id]);
      expect(rows[0].n).toBe(1);
    });

    it('refuses a second active pregnancy for the same woman', async () => {
      const reg = registration();
      await pushA(reg.all);
      const another = { ...reg.pregnancy, id: randomUUID() };

      const res = await pushA([another]);

      expect(statuses(res)).toEqual(['ACTIVE_PREGNANCY_EXISTS']);
    });

    it('accepts the deletion of a woman whatever happened to her household', async () => {
      const reg = registration();
      await pushA(reg.all);
      await pushA([{ ...reg.household, deleted: true }]);

      const res = await pushA([{ ...reg.woman, deleted: true }]);

      expect(statuses(res)).toEqual(['updated']);
    });

    it.each([
      ['a patient ID with spaces', 'women', { patientCode: 'LHW A 1' }],
      ['a woman without a name', 'women', { name: '' }],
      ['an age of 5', 'women', { age: 5 }],
      ['a contact number with letters', 'women', { contactNumber: 'call me' }],
      ['pregnancy month 0', 'pregnancies', { pregnancyMonthAtRegistration: 0 }],
      ['a date that does not exist', 'pregnancies', { registeredOn: '2026-02-30' }],
      ['a closing date on an active pregnancy', 'pregnancies', { closedOn: '2026-10-02' }],
      ['more C-sections than previous pregnancies', 'obstetric_history', { previousPregnancies: 1, previousCSections: 2 }],
      ['more stillbirths than previous pregnancies', 'obstetric_history', { previousPregnancies: 0, stillbirths: 1 }],
    ])('rejects %s with 400', async (_, table, change) => {
      const reg = registration();
      const record = { women: reg.woman, pregnancies: reg.pregnancy, obstetric_history: reg.history }[table];

      const res = await pushA([{ ...record, data: { ...record.data, ...change } }]);

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });
  });

  describe('GET /api/v1/women (portal, M10 FE-1)', () => {
    let mine;

    beforeAll(async () => {
      await resetDatabase();
      ids = await createFixtures();
      lhwA = tokenFor(ids.lhwA, 'lhw', ids.deviceA);
      lhwB = tokenFor(ids.lhwB, 'lhw', ids.deviceB);
      mine = registration({ code: 'LHW-A-0001', village: 'Chak Beli' });
      await pushA(mine.all);
      await pushA(registration({ code: 'LHW-A-0002', village: 'Dhok Syedan' }).all);
      await push(lhwB, ids.deviceB, registration({ code: 'LHW-B-0001', village: 'Other area' }).all);
    });

    it("shows a supervisor only their areas' women, with household, pregnancy and history", async () => {
      const res = await list(tokenFor(ids.supervisorA, 'supervisor'));

      expect(res.status).toBe(200);
      expect(res.body.total).toBe(2);
      expect(res.body.women.map((w) => w.patientCode).sort()).toEqual(['LHW-A-0001', 'LHW-A-0002']);
      const woman = res.body.women.find((w) => w.patientCode === 'LHW-A-0001');
      expect(woman).toMatchObject({
        name: 'Synthetic Woman',
        areaId: ids.areaA,
        household: { id: mine.household.id, village: 'Chak Beli', latitude: 33.6844, longitude: 73.0479 },
        registeredBy: { lhwCode: 'LHW-A' },
        pregnancy: { registeredOn: '2026-10-01', monthAtRegistration: 3, status: 'active' },
        obstetricHistory: { previousPregnancies: 2, previousCSections: 1, stillbirths: 0, knownConditions: 'Asthma' },
      });
    });

    it('searches by patient ID, name or village', async () => {
      const byVillage = await list(tokenFor(ids.supervisorA, 'supervisor'), '?search=chak');
      const byCode = await list(tokenFor(ids.admin, 'admin'), '?search=LHW-B');

      expect(byVillage.body.women.map((w) => w.patientCode)).toEqual(['LHW-A-0001']);
      expect(byCode.body.women.map((w) => w.patientCode)).toEqual(['LHW-B-0001']);
    });

    it('shows an admin every area', async () => {
      const res = await list(tokenFor(ids.admin, 'admin'));

      expect(res.body.total).toBe(3);
    });

    it('is not for LHWs', async () => {
      const res = await list(lhwA);

      expect(res.status).toBe(403);
    });
  });

  describe('patient numbers at sign-in (M2 FE-1)', () => {
    it("tells the app the LHW's highest patient number, so a new phone continues after it", async () => {
      await pushA(registration({ code: 'LHW-A-0041' }).all);
      await pushA(registration({ code: 'LHW-AX-0099' }).all); // another code that starts the same way
      await pushA(registration({ code: 'LHW-A-X7' }).all); // not a number

      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ username: 'lhw.a', password: PASSWORD, deviceId: ids.deviceA });

      expect(res.status).toBe(200);
      expect(res.body.user.lastPatientNumber).toBe(41);
    });
  });
});
