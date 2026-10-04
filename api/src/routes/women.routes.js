// M2 FE-1, FE-2: registered women for the supervisor portal.
const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requireRole } = require('../middleware/auth');
const womenController = require('../controllers/women.controller');

const router = Router();

const listSchema = Joi.object({
  search: Joi.string().trim().max(100).empty(''),
  limit: Joi.number().integer().min(1).max(500).default(200),
});

router.get('/', authenticate, requireRole('supervisor', 'admin'), validate({ query: listSchema }), womenController.list);

module.exports = router;
