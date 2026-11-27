const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requirePermission } = require('../middleware/auth');
const reports = require('../controllers/reports.controller');

const router = Router();
const listQuery = Joi.object({
  period: Joi.string().valid('weekly', 'monthly').default('weekly'),
  areaId: Joi.string().guid().lowercase(),
  before: Joi.string().pattern(/^[A-Za-z0-9_-]+$/).max(70),
  limit: Joi.number().integer().min(1).max(100).default(20),
});

router.use(authenticate, requirePermission('reports.view'));
router.get('/', validate({ query: listQuery }), reports.list);
router.get('/:id/download', validate({ params: Joi.object({ id: Joi.string().guid().required() }) }), reports.download);

module.exports = router;
