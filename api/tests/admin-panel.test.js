// M10 FE-3: the admin panel: supervisor and admin accounts, the geography
// structure, hospitals and referral centres, role permissions and the audit
// log. Every change must appear in the audit log (Phase 1 exit gate).
const request = require('supertest');
const { createApp } = require('../src/app');
const { loginThrottle } = require('../src/services/login-throttle');
const { PERMISSIONS } = require('../src/auth/permissions');
const { describeDb, resetDatabase, createFixtures, tokenFor, closePool, query } = require('./db');

const app = createApp();

describeDb('admin panel (M10 FE-3)', () => {
  let ids;
  let admin;
  const as = (token) => ({
    get: (path) => request(app).get(`/api/v1${path}`).set('Authorization', `Bearer ${token}`),
    post: (path, body) => request(app).post(`/api/v1${path}`).set('Authorization', `Bearer ${token}`).send(body),
    patch: (path, body) => request(app).patch(`/api/v1${path}`).set('Authorization', `Bearer ${token}`).send(body),
    delete: (path) => request(app).delete(`/api/v1${path}`).set('Authorization', `Bearer ${token}`),
  });
  const auditFor = async (entityId) =>
    (await query('SELECT action, user_id, entity_type, details FROM audit_log WHERE entity_id = $1 ORDER BY id', [entityId])).rows;

  beforeAll(async () => {
    await resetDatabase();
    ids = await createFixtures();
    admin = as(tokenFor(ids.admin, 'admin'));
  });

  beforeEach(() => loginThrottle.reset());

  afterAll(closePool);

  describe('role permissions', () => {
    it('lists the fixed roles and what each may do, from the same map the routes check', async () => {
      const res = await admin.get('/admin/roles');

      expect(res.status).toBe(200);
      expect(res.body.roles.map((r) => r.id)).toEqual(['lhw', 'supervisor', 'admin']);
      expect(res.body.permissions).toContainEqual(expect.objectContaining({ id: 'audit.view', roles: ['admin'] }));
      expect(res.body.permissions.map((p) => p.id)).toEqual(Object.keys(PERMISSIONS));
    });

    it.each([
      ['GET', '/admin/staff'],
      ['GET', '/admin/geography'],
      ['POST', '/admin/geography/districts'],
      ['GET', '/admin/hospitals'],
      ['GET', '/admin/referral-centres'],
      ['GET', '/admin/audit'],
      ['GET', '/admin/roles'],
    ])('refuses %s %s to supervisors and LHWs', async (method, path) => {
      for (const token of [tokenFor(ids.supervisorA, 'supervisor'), tokenFor(ids.lhwA, 'lhw', ids.deviceA)]) {
        const res = await as(token)[method.toLowerCase()](path, { name: 'X' });
        expect(res.status).toBe(403);
      }
    });
  });

  describe('supervisor and admin accounts', () => {
    let supervisor;

    it('creates a supervisor with areas, a chosen username and a one-time-shown password', async () => {
      const res = await admin.post('/admin/staff', {
        role: 'supervisor', username: 'Sup.Rawalpindi', fullName: 'Nadia Supervisor', phone: '0301 7654321', areaIds: [ids.areaA, ids.areaB],
      });

      expect(res.status).toBe(201);
      supervisor = res.body.staff;
      expect(supervisor).toMatchObject({ role: 'supervisor', username: 'sup.rawalpindi', fullName: 'Nadia Supervisor', isActive: true });
      expect(supervisor.areas.map((a) => a.name).sort()).toEqual(['Area A', 'Area B']);
      expect(res.body.credentials.password).toMatch(/^[A-Za-z0-9]{10}$/);
      const { rows: [row] } = await query('SELECT password_hash FROM users WHERE id = $1', [supervisor.id]);
      expect(row.password_hash).not.toContain(res.body.credentials.password);
      expect(await auditFor(supervisor.id)).toEqual([
        expect.objectContaining({ action: 'create', user_id: ids.admin, entity_type: 'users' }),
      ]);

      // The new supervisor signs in on the portal and sees both areas' data.
      const login = await request(app).post('/api/v1/auth/login')
        .send({ username: 'sup.rawalpindi', password: res.body.credentials.password });
      expect(login.status).toBe(200);
      expect(login.body.user.role).toBe('supervisor');
    });

    it('refuses a taken username, a supervisor without areas and an unknown area', async () => {
      const taken = await admin.post('/admin/staff', { role: 'admin', username: 'supervisor.a', fullName: 'Someone' });
      const noAreas = await admin.post('/admin/staff', { role: 'supervisor', username: 'sup.none', fullName: 'No Areas' });
      const unknown = await admin.post('/admin/staff', {
        role: 'supervisor', username: 'sup.unknown', fullName: 'Unknown Area', areaIds: ['6f1c2b8e-4d3a-4f5b-9c7d-2e1a0b9c8d7e'],
      });
      const badName = await admin.post('/admin/staff', { role: 'admin', username: '9 bad name', fullName: 'Bad' });

      expect([taken.status, taken.body.error.code]).toEqual([409, 'USERNAME_TAKEN']);
      expect([noAreas.status, noAreas.body.error.code]).toEqual([400, 'AREAS_REQUIRED']);
      expect([unknown.status, unknown.body.error.code]).toEqual([400, 'UNKNOWN_AREA']);
      expect(badName.status).toBe(400);
    });

    it('changes areas; the supervisor then sees only the new ones', async () => {
      const res = await admin.patch(`/admin/staff/${supervisor.id}`, { areaIds: [ids.areaB] });

      expect(res.status).toBe(200);
      expect(res.body.staff.areas.map((a) => a.id)).toEqual([ids.areaB]);
      const { rows } = await query('SELECT area_id FROM supervisor_areas WHERE supervisor_id = $1 AND deleted_at IS NULL', [supervisor.id]);
      expect(rows.map((r) => r.area_id)).toEqual([ids.areaB]);
      const edit = (await auditFor(supervisor.id)).find((row) => row.action === 'edit');
      expect(edit).toMatchObject({ user_id: ids.admin, details: { changes: { areaIds: { added: [], removed: [ids.areaA] } } } });
    });

    it('lists supervisors and admins with their areas and last login, filtered by role', async () => {
      const all = await admin.get('/admin/staff');
      const admins = await admin.get('/admin/staff?role=admin');

      expect(all.body.staff.map((s) => s.username)).toEqual(expect.arrayContaining(['sup.rawalpindi', 'supervisor.a', 'admin']));
      expect(all.body.staff.every((s) => s.role !== 'lhw')).toBe(true);
      expect(admins.body.staff.map((s) => s.username)).toEqual(['admin']);
    });

    it('turns a supervisor into an admin (areas dropped, signed out) and back', async () => {
      const promoted = await admin.patch(`/admin/staff/${supervisor.id}`, { role: 'admin' });
      expect(promoted.body.staff).toMatchObject({ role: 'admin', areas: [] });

      const demotedWithoutAreas = await admin.patch(`/admin/staff/${supervisor.id}`, { role: 'supervisor' });
      expect(demotedWithoutAreas.body.error.code).toBe('AREAS_REQUIRED');

      const demoted = await admin.patch(`/admin/staff/${supervisor.id}`, { role: 'supervisor', areaIds: [ids.areaA] });
      expect(demoted.body.staff).toMatchObject({ role: 'supervisor', areas: [expect.objectContaining({ id: ids.areaA })] });
    });

    it('never lets an admin lock themselves or everyone out', async () => {
      const ownRole = await admin.patch(`/admin/staff/${ids.admin}`, { role: 'supervisor', areaIds: [ids.areaA] });
      const ownDeactivate = await admin.post(`/admin/staff/${ids.admin}/deactivate`);

      expect([ownRole.status, ownRole.body.error.code]).toEqual([409, 'OWN_ACCOUNT']);
      expect([ownDeactivate.status, ownDeactivate.body.error.code]).toEqual([409, 'OWN_ACCOUNT']);
    });

    it('deactivates (refused at sign-in), activates and resets the password', async () => {
      const off = await admin.post(`/admin/staff/${supervisor.id}/deactivate`);
      expect(off.body.staff.isActive).toBe(false);
      const refused = await request(app).post('/api/v1/auth/login').send({ username: 'sup.rawalpindi', password: 'anything-at-all' });
      expect(refused.status).not.toBe(200);

      await admin.post(`/admin/staff/${supervisor.id}/activate`);
      const reset = await admin.post(`/admin/staff/${supervisor.id}/reset-password`);
      expect(reset.body.credentials.username).toBe('sup.rawalpindi');
      const login = await request(app).post('/api/v1/auth/login')
        .send({ username: 'sup.rawalpindi', password: reset.body.credentials.password });
      expect(login.status).toBe(200);

      const actions = (await auditFor(supervisor.id)).map((r) => r.details.change).filter(Boolean);
      expect(actions).toEqual(['deactivate', 'activate', 'password_reset']);
    });

    it('does not touch LHWs through this route', async () => {
      const res = await admin.patch(`/admin/staff/${ids.lhwA}`, { fullName: 'Not An LHW Route' });
      expect(res.status).toBe(404);
    });
  });

  describe('district, tehsil, Union Council and area structure', () => {
    let district;
    let tehsil;
    let uc;
    let area;

    it('builds a new branch level by level, each step audited', async () => {
      district = (await admin.post('/admin/geography/districts', { name: 'Chakwal' })).body.unit;
      tehsil = (await admin.post('/admin/geography/tehsils', { name: 'Talagang', parentId: district.id })).body.unit;
      uc = (await admin.post('/admin/geography/union-councils', { name: 'UC Talagang-1', parentId: tehsil.id })).body.unit;
      const res = await admin.post('/admin/geography/areas', { name: 'Area Talagang-1-A', parentId: uc.id });

      expect(res.status).toBe(201);
      area = res.body.unit;
      expect(area).toMatchObject({ name: 'Area Talagang-1-A', parentId: uc.id });
      for (const [unit, table] of [[district, 'districts'], [tehsil, 'tehsils'], [uc, 'union_councils'], [area, 'areas']]) {
        expect(await auditFor(unit.id)).toEqual([expect.objectContaining({ action: 'create', entity_type: table, user_id: ids.admin })]);
      }

      const tree = (await admin.get('/admin/geography')).body;
      const chakwal = tree.districts.find((d) => d.id === district.id);
      expect(chakwal.tehsils[0].unionCouncils[0].areas).toEqual([
        { id: area.id, name: 'Area Talagang-1-A', lhws: 0, supervisors: 0 },
      ]);

      // The new area can be given to an LHW straight away (M1 FE-1).
      const lhw = await admin.post('/admin/lhws', { fullName: 'New Area LHW', areaId: area.id });
      expect(lhw.status).toBe(201);
    });

    it('needs a parent below district level, and refuses a duplicate name among siblings', async () => {
      const noParent = await admin.post('/admin/geography/tehsils', { name: 'Orphan' });
      const unknownParent = await admin.post('/admin/geography/tehsils', { name: 'Orphan', parentId: area.id });
      const duplicate = await admin.post('/admin/geography/tehsils', { name: 'talagang', parentId: district.id });

      expect(noParent.status).toBe(400);
      expect(unknownParent.body.error.code).toBe('UNKNOWN_PARENT');
      expect([duplicate.status, duplicate.body.error.code]).toEqual([409, 'DUPLICATE_NAME']);
    });

    it('renames, with the old and new name in the audit log', async () => {
      const res = await admin.patch(`/admin/geography/union-councils/${uc.id}`, { name: 'UC Talagang-One' });

      expect(res.body.unit.name).toBe('UC Talagang-One');
      const [, edit] = await auditFor(uc.id);
      expect(edit.details.changes.name).toEqual({ from: 'UC Talagang-1', to: 'UC Talagang-One' });
    });

    it('refuses to delete what is still in use, and says what uses it', async () => {
      const usedArea = await admin.delete(`/admin/geography/areas/${area.id}`);
      const usedDistrict = await admin.delete(`/admin/geography/districts/${district.id}`);

      expect([usedArea.status, usedArea.body.error.code]).toEqual([409, 'IN_USE']);
      expect(usedArea.body.error.message).toContain('1 LHWs');
      expect(usedDistrict.body.error.details.uses).toEqual(['1 tehsils']);
    });

    it('deletes an unused unit softly, and creating the same name brings it back with its ID', async () => {
      const spare = (await admin.post('/admin/geography/areas', { name: 'Spare Area', parentId: uc.id })).body.unit;

      const removed = await admin.delete(`/admin/geography/areas/${spare.id}`);
      expect(removed.status).toBe(204);
      const { rows: [row] } = await query('SELECT deleted_at FROM areas WHERE id = $1', [spare.id]);
      expect(row.deleted_at).not.toBeNull();
      expect((await admin.get('/admin/areas')).body.areas.map((a) => a.id)).not.toContain(spare.id);

      const again = await admin.post('/admin/geography/areas', { name: 'Spare Area', parentId: uc.id });
      expect(again.body.unit.id).toBe(spare.id);
      expect((await auditFor(spare.id)).map((r) => r.action)).toEqual(['create', 'delete', 'edit']);
    });
  });

  describe('hospitals and referral centres', () => {
    let hospital;

    it('adds a hospital with its district, GPS and a server number, and audits it', async () => {
      const res = await admin.post('/admin/hospitals', {
        name: 'DHQ Hospital Area A', type: 'DHQ', districtId: (await query(
          'SELECT t.district_id FROM areas a JOIN union_councils uc ON uc.id = a.union_council_id JOIN tehsils t ON t.id = uc.tehsil_id WHERE a.id = $1',
          [ids.areaA],
        )).rows[0].district_id, address: 'Main Road', phone: '051 1234567', latitude: 33.6, longitude: 73.05,
      });

      expect(res.status).toBe(201);
      hospital = res.body.facility;
      expect(hospital).toMatchObject({ name: 'DHQ Hospital Area A', type: 'DHQ', latitude: 33.6, longitude: 73.05, area: null });
      expect(hospital.serverSeq).toBeGreaterThan(0);
      const { rows: [row] } = await query('SELECT created_by, created_on_device FROM hospitals WHERE id = $1', [hospital.id]);
      expect(row).toEqual({ created_by: ids.admin, created_on_device: null });
      expect(await auditFor(hospital.id)).toEqual([expect.objectContaining({ action: 'create', entity_type: 'hospitals' })]);
    });

    it('refuses half a GPS position and an area outside the district', async () => {
      const half = await admin.post('/admin/hospitals', { name: 'Half GPS', districtId: hospital.district.id, latitude: 33.6 });
      const elsewhere = await admin.post('/admin/hospitals', { name: 'Wrong Area', districtId: hospital.district.id, areaId: ids.areaB });

      expect(half.status).toBe(400);
      expect(elsewhere.body.error.code).toBe('AREA_NOT_IN_DISTRICT');
    });

    it('edits (new server number, so phones get the change) and deletes softly', async () => {
      const edited = await admin.patch(`/admin/hospitals/${hospital.id}`, { phone: '051 7654321', areaId: ids.areaA });
      expect(edited.body.facility).toMatchObject({ phone: '051 7654321', area: { id: ids.areaA, name: 'Area A' } });
      expect(edited.body.facility.serverSeq).toBeGreaterThan(hospital.serverSeq);

      expect((await admin.delete(`/admin/hospitals/${hospital.id}`)).status).toBe(204);
      expect((await admin.get('/admin/hospitals')).body.facilities).toEqual([]);
      expect((await auditFor(hospital.id)).map((r) => r.action)).toEqual(['create', 'edit', 'delete']);
    });

    it('needs a type for a referral centre and lists by district', async () => {
      const untyped = await admin.post('/admin/referral-centres', { name: 'Centre', districtId: hospital.district.id });
      const typed = await admin.post('/admin/referral-centres', {
        name: 'Nutrition Centre', type: 'Nutrition Rehabilitation Centre', districtId: hospital.district.id,
      });

      expect(untyped.status).toBe(400);
      expect(typed.status).toBe(201);
      const listed = await admin.get(`/admin/referral-centres?districtId=${hospital.district.id}`);
      expect(listed.body.facilities.map((f) => f.name)).toEqual(['Nutrition Centre']);
    });

    it('keeps a district with facilities from being deleted', async () => {
      const res = await admin.delete(`/admin/geography/districts/${hospital.district.id}`);
      expect(res.body.error.details.uses).toEqual(expect.arrayContaining(['1 referral centres']));
    });
  });

  describe('audit log viewer', () => {
    it('lists the newest first with who did it, and filters by user, action and record type', async () => {
      const all = await admin.get('/admin/audit?limit=200');
      expect(all.status).toBe(200);
      expect(all.body.entries.length).toBeGreaterThan(10);
      const ids_ = all.body.entries.map((e) => e.id);
      expect([...ids_].sort((a, b) => b - a)).toEqual(ids_);
      expect(all.body.actions).toContain('sync_conflict');
      expect(all.body.entityTypes).toEqual(expect.arrayContaining(['areas', 'hospitals', 'users']));

      const created = await admin.get('/admin/audit?action=create&entityType=hospitals');
      expect(created.body.entries).toHaveLength(1);
      expect(created.body.entries[0]).toMatchObject({
        action: 'create', entityType: 'hospitals', user: { username: 'admin', role: 'admin' }, details: { name: 'DHQ Hospital Area A' },
      });

      const byUser = await admin.get('/admin/audit?user=ADMIN&entityType=users&action=edit');
      expect(byUser.body.entries.length).toBeGreaterThan(0);
      expect(byUser.body.entries.every((e) => e.user.username === 'admin')).toBe(true);
      expect(byUser.body.entries.map((e) => e.entityLabel)).toContain('sup.rawalpindi');
    });

    it('records sign-ins too, and pages back with before', async () => {
      const logins = await admin.get('/admin/audit?action=login&limit=1');
      expect(logins.body.entries).toHaveLength(1);
      expect(logins.body.nextBefore).toBe(logins.body.entries[0].id);

      const next = await admin.get(`/admin/audit?action=login&limit=1&before=${logins.body.nextBefore}`);
      expect(next.body.entries[0].id).toBeLessThan(logins.body.entries[0].id);
    });

    it('filters by whole days, Pakistan time', async () => {
      const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Karachi' }).format(new Date());
      const inToday = await admin.get(`/admin/audit?from=${today}&to=${today}&limit=5`);
      const beforeToday = await admin.get('/admin/audit?to=2020-01-01');

      expect(inToday.body.entries.length).toBeGreaterThan(0);
      expect(beforeToday.body.entries).toEqual([]);
    });

    it('validates its filters', async () => {
      expect((await admin.get('/admin/audit?action=hack')).status).toBe(400);
      expect((await admin.get('/admin/audit?from=yesterday')).status).toBe(400);
    });
  });
});
