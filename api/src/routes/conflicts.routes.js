// M3 FE-2, M10 base: the sync conflict review queue for supervisors and admins.
const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requirePermission } = require('../middleware/auth');
const conflictsController = require('../controllers/conflicts.controller');
const { RESOLUTIONS } = require('../services/conflicts.service');

const router = Router();

const listQuery = Joi.object({
  status: Joi.string().valid('pending', 'resolved', 'all').default('pending'),
});
const idParams = Joi.object({ id: Joi.string().guid().required() });
const resolveBody = Joi.object({
  resolution: Joi.string().valid(...RESOLUTIONS).required(),
});

router.use(authenticate, requirePermission('conflicts.resolve'));
router.get('/', validate({ query: listQuery }), conflictsController.list);
router.post('/:id/resolve', validate({ params: idParams, body: resolveBody }), conflictsController.resolve);

module.exports = router;
