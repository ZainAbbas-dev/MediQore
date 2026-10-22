// M10 FE-3: an admin may give a supervisor some administration permissions;
// they then work only on the supervisor's own areas. Roles, supervisor and admin
// accounts and the geography stay with admins (auth/permissions.js).
const request = require('supertest');
const { createApp } = require('../src/app');
const { describeDb, resetDatabase, createFixtures, tokenFor, closePool, query } = require('./db');

const app = createApp();

describeDb('administration for supervisors (M10 FE-3)', () => {
  let ids;
  let admin;
  const as = (token) => ({
    get: (path) => request(app).get(`/api/v1${path}`).set('Authorization', `Bearer ${token}`),
    post: (path, body) => request(app).post(`/api/v1${path}`).set('Authorization', `Bearer ${token}`).send(body),
    patch: (path, body) => request(app).patch(`/api/v1${path}`).set('Authorization', `Bearer ${token}`).send(body),
    put: (path, body) => request(app).put(`/api/v1${path}`).set('Authorization', `Bearer ${token}`).send(body),
    delete: (path) => request(app).delete(`/api/v1${path}`).set('Authorization', `Bearer ${token}`),
  });

  afterAll(closePool);

  describe('administration given to a supervisor covers only their areas', () => {
    let supervisor;
    const grant = (permission, granted) =>
      admin.put('/admin/roles/permissions', { changes: [{ role: 'supervisor', permission, granted }] });

    beforeAll(async () => {
      await resetDatabase();
      ids = await createFixtures();
      admin = as(tokenFor(ids.admin, 'admin'));
      supervisor = as(tokenFor(ids.supervisorA, 'supervisor'));
      for (const permission of ['accounts.manage', 'facilities.manage', 'audit.view']) await grant(permission, true);
    });



    it('LHW accounts: lists, edits and places LHWs only in their areas', async () => {
      const listed = await supervisor.get('/admin/lhws');
      expect(listed.status).toBe(200);
      expect(listed.body.lhws.map((l) => l.lhwCode)).toEqual(['LHW-A']);
      expect((await supervisor.get('/admin/areas')).body.areas.map((a) => a.id)).toEqual([ids.areaA]);

      expect((await supervisor.post(`/admin/lhws/${ids.lhwB}/reset-password`)).status).toBe(404);
      expect((await supervisor.post(`/admin/lhws/${ids.lhwB}/activation-code`)).status).toBe(404);
      expect((await supervisor.patch(`/admin/lhws/${ids.lhwA}`, { areaId: ids.areaB })).body.error.code).toBe('OUT_OF_AREA');
      expect((await supervisor.post('/admin/lhws', { fullName: 'Synthetic LHW', areaId: ids.areaB })).body.error.code).toBe('OUT_OF_AREA');

      const created = await supervisor.post('/admin/lhws', { fullName: 'Synthetic LHW', areaId: ids.areaA });
      expect(created.status).toBe(201);
      expect(created.body.lhw.area.id).toBe(ids.areaA);
      expect((await supervisor.get('/admin/staff')).status).toBe(403);
    });

    it("hospitals: only the districts of their areas", async () => {
      const district = async (areaId) => (await query(
        `SELECT t.district_id FROM areas a JOIN union_councils uc ON uc.id = a.union_council_id
         JOIN tehsils t ON t.id = uc.tehsil_id WHERE a.id = $1`, [areaId])).rows[0].district_id;
      const [mine, other] = [await district(ids.areaA), await district(ids.areaB)];
      const elsewhere = await admin.post('/admin/hospitals', { name: 'Synthetic DHQ B', districtId: other });

      const created = await supervisor.post('/admin/hospitals', { name: 'Synthetic THQ A', districtId: mine });
      expect(created.status).toBe(201);
      expect((await supervisor.post('/admin/hospitals', { name: 'Synthetic X', districtId: other })).body.error.code).toBe('OUT_OF_AREA');
      const listed = (await supervisor.get('/admin/hospitals')).body.facilities.map((f) => f.name);
      expect(listed).toContain('Synthetic THQ A');
      expect(listed).not.toContain('Synthetic DHQ B');
      expect((await supervisor.patch(`/admin/hospitals/${elsewhere.body.facility.id}`, { name: 'Synthetic Y' })).status).toBe(404);
      expect((await supervisor.delete(`/admin/hospitals/${elsewhere.body.facility.id}`)).status).toBe(404);
    });

    it('audit log: only what they and the LHWs of their areas did', async () => {
      await admin.post(`/admin/lhws/${ids.lhwB}/reset-password`);
      await supervisor.post(`/admin/lhws/${ids.lhwA}/reset-password`);

      const entries = (await supervisor.get('/admin/audit')).body.entries;
      expect(entries.length).toBeGreaterThan(0);
      expect(entries.every((e) => [ids.supervisorA, ids.lhwA].includes(e.user?.id))).toBe(true);
    });
  });
});
