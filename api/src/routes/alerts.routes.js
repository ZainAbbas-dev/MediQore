const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requirePermission, requireRole } = require('../middleware/auth');
const controller = require('../controllers/alerts.controller');

const router = Router();
const idParams = Joi.object({ id: Joi.string().guid().required() });
const listQuery = Joi.object({
  districtId: Joi.string().guid(),
  tehsilId: Joi.string().guid(),
  unionCouncilId: Joi.string().guid(),
  lhwId: Joi.string().guid(),
  days: Joi.number().integer().min(1).max(366),
  emergencyOnly: Joi.boolean().default(false),
  limit: Joi.number().integer().min(1).max(100).default(50),
  before: Joi.string().pattern(/^[1-9][0-9]{0,18}$/).custom((value, helpers) =>
    BigInt(value) <= 9223372036854775807n ? value : helpers.error('any.invalid')),
});
const subscriptionBody = Joi.object({
  token: Joi.string().trim().min(1).max(4096).required(),
});

const viewAlerts = requirePermission('alerts.view');
router.use(authenticate);
router.get('/', viewAlerts, validate({ query: listQuery }), controller.list);
router.post('/:id/acknowledge', viewAlerts, requirePermission('alerts.acknowledge'), validate({ params: idParams }), controller.acknowledge);
router.post('/push/subscriptions', viewAlerts, requireRole('supervisor'), validate({ body: subscriptionBody }), controller.subscribe);
router.delete('/push/subscriptions/:id', requireRole('supervisor'), validate({ params: idParams }), controller.unsubscribe);

module.exports = router;
