// M10 FE-1 (Phase 1 base): dashboard counts, LHW activity and the filters of
// the map, for supervisors (their areas) and admins.
const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requirePermission } = require('../middleware/auth');
const dashboardController = require('../controllers/dashboard.controller');

const router = Router();

// The dashboard filters; the period applies to the map only (GET /households).
const placeQuery = Joi.object({
  districtId: Joi.string().guid(),
  tehsilId: Joi.string().guid(),
  unionCouncilId: Joi.string().guid(),
  lhwId: Joi.string().guid(),
});

router.use(authenticate, requirePermission('records.view'));
router.get('/summary', validate({ query: placeQuery }), dashboardController.summary);
router.get('/filters', dashboardController.filters);
router.get('/lhw-activity', validate({ query: placeQuery }), dashboardController.lhwActivity);

module.exports = router;
