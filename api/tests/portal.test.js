const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const request = require('supertest');
const { createApp } = require('../src/app');

// Staging serves the built portal next to the API (PORTAL_DIR, docs/staging.md).
describe('serving the portal (staging)', () => {
  let portalDir;

  beforeAll(() => {
    portalDir = fs.mkdtempSync(path.join(os.tmpdir(), 'mediqore-portal-'));
    fs.writeFileSync(path.join(portalDir, 'index.html'), '<!doctype html><title>MediQore portal</title>');
    fs.mkdirSync(path.join(portalDir, 'assets'));
    fs.writeFileSync(path.join(portalDir, 'assets', 'app.js'), 'console.log("portal");');
  });
  afterAll(() => fs.rmSync(portalDir, { recursive: true, force: true }));

  it('serves the portal and its files', async () => {
    const app = createApp({ portalDir });

    const home = await request(app).get('/');
    expect(home.status).toBe(200);
    expect(home.text).toContain('MediQore portal');

    const script = await request(app).get('/assets/app.js');
    expect(script.status).toBe(200);
    expect(script.headers['content-type']).toMatch(/javascript/);
  });

  it('answers any other page address with the portal, so a reload works', async () => {
    const res = await request(createApp({ portalDir })).get('/admin/audit');

    expect(res.status).toBe(200);
    expect(res.text).toContain('MediQore portal');
  });

  it('keeps the API and its JSON errors under /api', async () => {
    const app = createApp({ portalDir });

    expect((await request(app).get('/api/v1/health')).body).toMatchObject({ status: 'ok' });
    const missing = await request(app).get('/api/v1/does-not-exist');
    expect(missing.status).toBe(404);
    expect(missing.body.error.code).toBe('NOT_FOUND');
    expect((await request(app).get('/api/other')).status).toBe(404);
    expect((await request(app).post('/admin/audit')).status).toBe(404);
  });

  it('is off unless PORTAL_DIR is set', async () => {
    expect((await request(createApp({ portalDir: null })).get('/')).status).toBe(404);
  });

  it('serves the portal over HTTPS only when HTTPS is required', async () => {
    const app = createApp({ portalDir, requireHttps: true, trustProxy: 1 });

    expect((await request(app).get('/')).status).toBe(403);
    const secure = await request(app).get('/').set('X-Forwarded-Proto', 'https');
    expect(secure.status).toBe(200);
    expect(secure.headers['strict-transport-security']).toBeDefined();
  });
});
