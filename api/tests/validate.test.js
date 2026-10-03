const express = require('express');
const Joi = require('joi');
const request = require('supertest');
const validate = require('../src/middleware/validate');
const { notFound, errorHandler } = require('../src/middleware/error-handler');

// A throwaway app that echoes what the controller receives after validation.
function buildApp(schemas) {
  const app = express();
  app.use(express.json());
  app.post('/items/:id', validate(schemas), (req, res) => {
    res.json({ params: req.params, query: req.query, body: req.body });
  });
  app.use(notFound);
  app.use(errorHandler);
  return app;
}

const schemas = {
  params: Joi.object({ id: Joi.string().guid({ version: 'uuidv4' }).required() }),
  query: Joi.object({ limit: Joi.number().integer().min(1).max(100).default(20) }),
  body: Joi.object({
    name: Joi.string().trim().min(1).required(),
    systolicBp: Joi.number().integer().min(60).max(250).required(),
  }),
};

const ID = '6f1c2b8e-4d3a-4f5b-9c7d-2e1a0b9c8d7e';

describe('validate middleware', () => {
  it('passes sanitised values to the controller', async () => {
    const res = await request(buildApp(schemas))
      .post(`/items/${ID}?limit=5`)
      .send({ name: '  Sample  ', systolicBp: 120, unexpected: 'dropped' });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      params: { id: ID },
      query: { limit: 5 },
      body: { name: 'Sample', systolicBp: 120 },
    });
  });

  it('applies defaults from the schema', async () => {
    const res = await request(buildApp(schemas)).post(`/items/${ID}`).send({ name: 'A', systolicBp: 110 });

    expect(res.status).toBe(200);
    expect(res.body.query).toEqual({ limit: 20 });
  });

  it('rejects an invalid request with every problem listed', async () => {
    const res = await request(buildApp(schemas))
      .post('/items/not-a-uuid?limit=500')
      .send({ systolicBp: 300 });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ in: 'params', path: 'id' }),
        expect.objectContaining({ in: 'query', path: 'limit' }),
        expect.objectContaining({ in: 'body', path: 'name' }),
        expect.objectContaining({ in: 'body', path: 'systolicBp' }),
      ]),
    );
  });

  it('treats a missing body as empty', async () => {
    const res = await request(buildApp({ body: schemas.body })).post(`/items/${ID}`);

    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d) => d.path)).toEqual(['name', 'systolicBp']);
  });
});
