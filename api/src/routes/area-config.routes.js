const { Router } = require('express');
const Joi = require('joi');
const { authenticate, requirePermission } = require('../middleware/auth');
const validate = require('../middleware/validate');
const controller = require('../controllers/area-config.controller');

const router = Router();
router.use(authenticate);

const uuid = Joi.string().lowercase().pattern(/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/);
const areaParams = Joi.object({ areaId: uuid.required() });
const roundParams = Joi.object({ roundId: uuid.required() });
const phone = Joi.string().trim().max(24).pattern(/^\+?[0-9](?:[ -]?[0-9]){7,14}$/);
const contactBody = Joi.object({
  supervisorUserId: uuid.allow(null).default(null),
  supervisorPhone: phone.required(),
  secondaryName: Joi.string().trim().max(150).allow(null).default(null),
  secondaryPhone: phone.allow(null).default(null),
  escalateAfterMinutes: Joi.number().integer().min(1).max(32767).default(15),
});

const date = Joi.string().pattern(/^(?!0000)\d{4}-\d{2}-\d{2}$/).custom((value, helpers) => {
  const parsed = new Date(value);
  if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) {
    return helpers.error('date.format', { format: 'YYYY-MM-DD' });
  }
  return value;
});
const roundFields = {
  name: Joi.string().trim().min(2).max(150),
  startsOn: date,
  endsOn: date,
  areaIds: Joi.array().items(uuid).min(1).unique(),
};
const newRound = Joi.object(roundFields).fork(Object.keys(roundFields), (field) => field.required());
const editRound = Joi.object(roundFields).min(1);

const escalation = requirePermission('escalation.manage');
router.get('/escalation-contacts/options', escalation, controller.contactOptions);
router.get('/escalation-contacts', escalation, controller.listContacts);
router.get('/escalation-contacts/:areaId', escalation, validate({ params: areaParams }), controller.getContact);
router.put('/escalation-contacts/:areaId', escalation, validate({ params: areaParams, body: contactBody }), controller.saveContact);
router.delete('/escalation-contacts/:areaId', escalation, validate({ params: areaParams }), controller.deleteContact);

const campaigns = requirePermission('campaigns.manage');
router.get('/campaign-rounds/options', campaigns, controller.campaignOptions);
router.get('/campaign-rounds', campaigns, controller.listRounds);
router.post('/campaign-rounds', campaigns, validate({ body: newRound }), controller.createRound);
router.patch('/campaign-rounds/:roundId', campaigns, validate({ params: roundParams, body: editRound }), controller.updateRound);
router.delete('/campaign-rounds/:roundId', campaigns, validate({ params: roundParams }), controller.deleteRound);

module.exports = router;
