// M10 FE-1 (Phase 1 base): dashboard counts, LHW activity and the filters of
// the map, for supervisors (their areas) and admins.
const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requirePermission } = require('../middleware/auth');
const dashboardController = require('../controllers/dashboard.controller');

const router = Router();

const activityQuery = Joi.object({
  districtId: Joi.string().guid(),
  unionCouncilId: Joi.string().guid(),
});

router.use(authenticate, requirePermission('records.view'));
router.get('/summary', dashboardController.summary);
router.get('/filters', dashboardController.filters);
router.get('/lhw-activity', validate({ query: activityQuery }), dashboardController.lhwActivity);

module.exports = router;
