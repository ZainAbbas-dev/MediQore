const { Router } = require('express');
const Joi = require('joi');
const { authenticate, requirePermission } = require('../middleware/auth');
const validate = require('../middleware/validate');
const controller = require('../controllers/child-analytics.controller');

const router = Router();
const id = Joi.string().guid();
const date = Joi.string().pattern(/^\d{4}-\d{2}-\d{2}$/).custom((value, helpers) => {
  const parsed = new Date(value);
  return !value.startsWith('0000') && !Number.isNaN(parsed.getTime()) && parsed.toISOString().startsWith(value)
    ? value : helpers.error('string.isoDate');
});
const places = { districtId: id, areaId: id, tehsilId: id, unionCouncilId: id, lhwId: id };
const period = { startDate: date, endDate: date, days: Joi.number().integer().min(1).max(366) };
const pagination = (maxLimit) => ({
  page: Joi.number().integer().min(1).max(1_000_000),
  limit: Joi.number().integer().min(1).max(maxLimit),
});

function activityQuery(fields = {}) {
  return Joi.object({ ...places, ...period, ...fields })
    .custom((value, helpers) => value.startDate && value.endDate && value.startDate > value.endDate
      ? helpers.message('Start date must be on or before end date') : value);
}

router.use(authenticate, requirePermission('records.view'));
router.get('/filters', validate({ query: Joi.object(places) }), controller.filters);
router.get('/children', validate({ query: activityQuery({ ...pagination(100), followUp: Joi.valid('zero-dose', 'no-opv') }) }), controller.children);
router.get('/coverage', validate({ query: activityQuery() }), controller.coverage);
router.get('/polio', validate({ query: activityQuery({ ...pagination(100), roundId: id }) }), controller.polio);
router.get('/hotspots', validate({ query: activityQuery(pagination(2000)) }), controller.hotspots);

module.exports = router;
