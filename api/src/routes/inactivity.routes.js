const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requirePermission } = require('../middleware/auth');
const { getInactivity, listExclusions, setExclusion } = require('../services/inactivity.service');

const router = Router();
const lhwId = Joi.string().guid().required();
const weekStart = Joi.string().pattern(/^\d{4}-\d{2}-\d{2}$/).custom((value, helpers) => {
  const date = new Date(`${value}T00:00:00Z`);
  return date.getUTCDay() === 1 && date.toISOString().slice(0, 10) === value && !value.startsWith('0000')
    ? value : helpers.error('any.invalid');
}).messages({ 'any.invalid': '{{#label}} must be a valid Monday in YYYY-MM-DD format' }).required();
const weekParams = Joi.object({ lhwId, weekStart });
const exclusionBody = Joi.object({ kind: Joi.string().valid('leave', 'campaign').required() });

router.use(authenticate, requirePermission('records.view'));

router.get('/', async (req, res) => {
  res.json(await getInactivity(req.user));
});
router.get('/:lhwId/exclusions', validate({ params: Joi.object({ lhwId }) }), async (req, res) => {
  res.json(await listExclusions(req.user, req.params.lhwId));
});
router.put('/:lhwId/exclusions/:weekStart', requirePermission('inactivity.manage'),
  validate({ params: weekParams, body: exclusionBody }), async (req, res) => {
    res.json(await setExclusion(req.user, req.params.lhwId, req.params.weekStart, req.body.kind));
  });
router.delete('/:lhwId/exclusions/:weekStart', requirePermission('inactivity.manage'),
  validate({ params: weekParams }), async (req, res) => {
    await setExclusion(req.user, req.params.lhwId, req.params.weekStart, null);
    res.status(204).end();
  });

module.exports = router;
