// M3 FE-2: what the phone pulls besides records (GET /sync/config), and M2 FE-1:
// the estimated delivery date that comes with every pregnancy.
const { randomUUID } = require('node:crypto');
const request = require('supertest');
const { createApp } = require('../src/app');
const { describeDb, resetDatabase, createFixtures, tokenFor, closePool, query } = require('./db');
const RULES = require('../../clinical-rules/clinical-rules.json');

const app = createApp();

describeDb('sync configuration and pregnancy dates', () => {
  let ids;
  let lhwA;

  const get = (token, path) => request(app).get(`/api/v1${path}`).set('Authorization', `Bearer ${token}`);
  const push = (records) =>
    request(app).post('/api/v1/sync/push').set('Authorization', `Bearer ${lhwA}`).send({ deviceId: ids.deviceA, records });

  beforeAll(async () => {
    await resetDatabase();
    ids = await createFixtures();
    lhwA = tokenFor(ids.lhwA, 'lhw', ids.deviceA);
  });

  afterAll(closePool);

  describe('GET /sync/config (M3 FE-2)', () => {
    beforeAll(async () => {
      const { rows: [place] } = await query(
        `SELECT t.district_id FROM areas a JOIN union_councils u ON u.id = a.union_council_id
         JOIN tehsils t ON t.id = u.tehsil_id WHERE a.id = $1`,
        [ids.areaA],
      );
      const { rows: [other] } = await query(
        `SELECT t.district_id FROM areas a JOIN union_councils u ON u.id = a.union_council_id
         JOIN tehsils t ON t.id = u.tehsil_id WHERE a.id = $1`,
        [ids.areaB],
      );
      await query(
        `INSERT INTO hospitals (created_by, district_id, name, facility_type, phone) VALUES
           ($1, $2, 'Synthetic DHQ', 'DHQ', '0000-1111111'), ($1, $3, 'Other District THQ', 'THQ', '0000-2222222')`,
        [ids.admin, place.district_id, other.district_id],
      );
      await query(
        `INSERT INTO campaigns (area_id, created_by, name, starts_on, ends_on) VALUES
           ($1, $2, 'Round old', '2025-01-01', '2025-01-05'), ($1, $2, 'Round next', current_date, current_date + 4)`,
        [ids.areaA, ids.admin],
      );
      await query(
        `INSERT INTO escalation_contacts (area_id, created_by, supervisor_phone, secondary_name, secondary_phone)
         VALUES ($1, $2, '0000-3333333', 'Synthetic DHQ', '0000-1111111')`,
        [ids.areaA, ids.admin],
      );
    });

    it("gives the phone its district's facilities, its area's contacts and current rounds, and the rules table", async () => {
      const res = await get(lhwA, '/sync/config');

      expect(res.status).toBe(200);
      expect(res.body.unchanged).toBe(false);
      expect(res.body.configVersion).toMatch(/^[0-9a-f]{64}$/);
      expect(res.body.facilities.map((f) => f.name)).toEqual(['Synthetic DHQ']);
      expect(res.body.escalationContact).toMatchObject({ secondaryName: 'Synthetic DHQ', escalateAfterMinutes: 15 });
      expect(res.body.campaigns.map((c) => c.name)).toEqual(['Round next']);
      expect(res.body.clinicalRules.version).toBe(RULES.version);
    });

    it('answers only the hash when the phone already has this configuration', async () => {
      const { body: first } = await get(lhwA, '/sync/config');

      const res = await get(lhwA, `/sync/config?have=${first.configVersion}`);

      expect(res.body).toEqual({ configVersion: first.configVersion, unchanged: true });
    });

    it('serves the newest loaded rules version instead of the bundled file', async () => {
      const content = { ...RULES, version: '0.9.0' };
      await query(
        `INSERT INTO clinical_rules_versions (version, content, content_sha256, effective_from)
         VALUES ('0.9.0', $1, repeat('a', 64), current_date)`,
        [content],
      );

      expect((await get(lhwA, '/sync/config')).body.clinicalRules.version).toBe('0.9.0');
    });

    it('is for activated phones only', async () => {
      expect((await get(tokenFor(ids.supervisorA, 'supervisor'), '/sync/config')).status).toBe(403);
    });
  });

  describe('pregnancy dates (M2 FE-1)', () => {
    const pregnancy = (data) => {
      const household = { table: 'households', id: randomUUID(), createdOnDevice: '2026-10-01T09:30:00.000Z', data: { village: 'V' } };
      const woman = {
        table: 'women', id: randomUUID(), createdOnDevice: '2026-10-01T09:30:00.000Z',
        data: { householdId: household.id, patientCode: `LHW-A-01-${randomUUID().slice(0, 4)}`, name: randomUUID() },
      };
      const record = {
        table: 'pregnancies', id: randomUUID(), createdOnDevice: '2026-10-01T09:30:00.000Z',
        data: { womanId: woman.id, registeredOn: '2026-10-01', pregnancyMonthAtRegistration: 3, ...data },
      };
      return [household, woman, record];
    };

    it('estimates the date from the month for an app that sends none', async () => {
      const records = pregnancy({});

      expect((await push(records)).status).toBe(200);
      const { rows: [row] } = await query('SELECT estimated_delivery_date, edd_basis FROM pregnancies WHERE id = $1', [records[2].id]);
      // Month 3 is taken as 10.9 weeks, so 29.1 weeks (204 days) remain.
      expect(row).toEqual({ estimated_delivery_date: '2027-04-23', edd_basis: 'month' });
    });

    it('stores a known EDD as given', async () => {
      const records = pregnancy({ reportedEdd: '2027-04-10', eddBasis: 'edd', estimatedDeliveryDate: '2027-04-10' });

      await push(records);

      const { rows: [row] } = await query('SELECT reported_edd, edd_basis FROM pregnancies WHERE id = $1', [records[2].id]);
      expect(row).toEqual({ reported_edd: '2027-04-10', edd_basis: 'edd' });
    });

    it.each([
      ['an LMP date without its basis', { lmpDate: '2026-07-10', eddBasis: 'month', estimatedDeliveryDate: '2027-04-16' }],
      ['an EDD basis without the reported date', { eddBasis: 'edd', estimatedDeliveryDate: '2027-04-16' }],
      ['a date that gives 50 weeks at registration', { lmpDate: '2025-10-16', eddBasis: 'lmp', estimatedDeliveryDate: '2026-07-23' }],
      ['an EDD in the past', { reportedEdd: '2026-09-01', eddBasis: 'edd', estimatedDeliveryDate: '2026-09-01' }],
    ])('refuses %s', async (_, data) => {
      expect((await push(pregnancy(data))).status).toBe(400);
    });
  });
});
