const request = require('supertest');
const { createApp } = require('../src/app');

describe('GET /api/v1/health', () => {
  it('reports the API as up', async () => {
    const res = await request(createApp()).get('/api/v1/health');

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ status: 'ok', service: 'mediqore-api' });
    expect(typeof res.body.version).toBe('string');
    expect(res.headers['x-powered-by']).toBeUndefined();
  });
});

describe('unknown routes', () => {
  it('returns 404 NOT_FOUND in the standard error shape', async () => {
    const res = await request(createApp()).get('/api/v1/does-not-exist');

    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: { code: 'NOT_FOUND', message: 'Route not found' } });
  });

  it('only serves the API under /api/v1', async () => {
    const res = await request(createApp()).get('/health');

    expect(res.status).toBe(404);
  });
});
