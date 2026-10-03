const express = require('express');
const request = require('supertest');
const AppError = require('../src/utils/app-error');
const { createApp } = require('../src/app');
const { notFound, errorHandler } = require('../src/middleware/error-handler');

function buildApp(handler) {
  const app = express();
  app.use(express.json());
  app.get('/boom', handler);
  app.use(notFound);
  app.use(errorHandler);
  return app;
}

describe('errorHandler', () => {
  it('sends an AppError with its status, code and details', async () => {
    const app = buildApp(() => {
      throw new AppError(409, 'CONFLICT', 'Record already exists', [{ path: 'id' }]);
    });

    const res = await request(app).get('/boom');

    expect(res.status).toBe(409);
    expect(res.body).toEqual({
      error: { code: 'CONFLICT', message: 'Record already exists', details: [{ path: 'id' }] },
    });
  });

  it('catches errors from async handlers', async () => {
    const app = buildApp(async () => {
      await Promise.resolve();
      throw new AppError(404, 'NOT_FOUND', 'Woman not found');
    });

    const res = await request(app).get('/boom');

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('hides unexpected errors behind a generic 500', async () => {
    const app = buildApp(() => {
      throw new Error('connection string with a password');
    });

    const res = await request(app).get('/boom');

    expect(res.status).toBe(500);
    expect(res.body).toEqual({ error: { code: 'INTERNAL_ERROR', message: 'Something went wrong' } });
  });

  it('answers malformed JSON with 400 INVALID_JSON', async () => {
    const res = await request(createApp())
      .post('/api/v1/health')
      .set('Content-Type', 'application/json')
      .send('{"name": ');

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_JSON');
  });
});
