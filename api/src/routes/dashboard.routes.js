// M10 FE-1 (Phase 1 base): dashboard counts, LHW activity and the filters of
// the map, for supervisors (their areas) and admins.
const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requirePermission } = require('../middleware/auth');
const { maternal } = require('../services/dashboard-maternal.service');
const dashboardController = require('../controllers/dashboard.controller');

const router = Router();

// Common filters for the dashboard, map and LHW activity.
const placeQuery = Joi.object({
  districtId: Joi.string().guid(),
  tehsilId: Joi.string().guid(),
  unionCouncilId: Joi.string().guid(),
  lhwId: Joi.string().guid(),
  days: Joi.number().integer().min(1).max(366),
});

router.use(authenticate, requirePermission('records.view'));
router.get('/maternal', validate({ query: placeQuery.keys({
  limit: Joi.number().integer().min(1).max(50),
  offset: Joi.number().integer().min(0).max(10000),
}) }), async (req, res) => res.json(await maternal(req.user, req.query)));
router.get('/summary', validate({ query: placeQuery }), dashboardController.summary);
router.get('/filters', dashboardController.filters);
router.get('/lhw-activity', validate({ query: placeQuery }), dashboardController.lhwActivity);

module.exports = router;
