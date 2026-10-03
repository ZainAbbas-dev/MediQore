// M3 FE-2: offline sync endpoints (P0-6).
const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requireRole } = require('../middleware/auth');
const { TABLES, dataSchema } = require('../sync/tables');
const syncController = require('../controllers/sync.controller');

const router = Router();

// Devices push their outbox in batches of about 100 (roadmap, Offline sync).
const MAX_BATCH = 100;

const uuidV4 = Joi.string().guid({ version: 'uuidv4' });

const recordSchema = Joi.object({
  table: Joi.string().valid(...Object.keys(TABLES)).required(),
  id: uuidV4.required(),
  createdOnDevice: Joi.date().iso().required(),
  deleted: Joi.boolean().default(false),
  data: Joi.when('table', {
    switch: Object.entries(TABLES).map(([table, def]) => ({ is: table, then: dataSchema(def).required() })),
  }),
});

const pushSchema = Joi.object({
  deviceId: uuidV4.required(),
  records: Joi.array().items(recordSchema).min(1).max(MAX_BATCH).unique('id').required(),
});

const pullSchema = Joi.object({
  since: Joi.number().integer().min(0).default(0),
  limit: Joi.number().integer().min(1).max(500).default(100),
});

router.use(authenticate, requireRole('lhw'));
router.post('/push', validate({ body: pushSchema }), syncController.push);
router.get('/pull', validate({ query: pullSchema }), syncController.pull);

module.exports = router;
