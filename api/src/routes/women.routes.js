// M2 FE-1, FE-2: registered women for the supervisor portal, and each woman's
// visits (M3 FE-1, M10 FE-1).
const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requirePermission } = require('../middleware/auth');
const womenController = require('../controllers/women.controller');

const router = Router();

const listSchema = Joi.object({
  search: Joi.string().trim().max(100).empty(''),
  limit: Joi.number().integer().min(1).max(500).default(200),
});

const idSchema = Joi.object({ id: Joi.string().guid().required() });

router.get('/', authenticate, requirePermission('records.view'), validate({ query: listSchema }), womenController.list);
router.get(
  '/:id/visits',
  authenticate,
  requirePermission('records.view'),
  validate({ params: idSchema }),
  womenController.visits,
);

module.exports = router;
