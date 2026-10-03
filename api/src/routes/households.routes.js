const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requireRole } = require('../middleware/auth');
const householdsController = require('../controllers/households.controller');

const router = Router();

const listSchema = Joi.object({
  limit: Joi.number().integer().min(1).max(500).default(200),
});

router.get('/', authenticate, requireRole('supervisor', 'admin'), validate({ query: listSchema }), householdsController.list);

module.exports = router;
