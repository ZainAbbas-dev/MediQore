const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requirePermission } = require('../middleware/auth');
const householdsController = require('../controllers/households.controller');

const router = Router();

// M10 FE-1: the dashboard map's filters. `days` is the time period: households
// the server received in the last so many days.
const listSchema = Joi.object({
  limit: Joi.number().integer().min(1).max(500).default(200),
  districtId: Joi.string().guid(),
  unionCouncilId: Joi.string().guid(),
  lhwId: Joi.string().guid(),
  days: Joi.number().integer().min(1).max(366),
});

router.get('/', authenticate, requirePermission('records.view'), validate({ query: listSchema }), householdsController.list);

module.exports = router;
