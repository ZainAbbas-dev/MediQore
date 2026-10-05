// M1 FE-2, decision 0002: phones waiting for approval, and their one-time codes.
const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requirePermission } = require('../middleware/auth');
const devicesController = require('../controllers/devices.controller');

const router = Router();

router.use(authenticate, requirePermission('devices.approve'));
router.get('/pending', devicesController.listPending);
router.post(
  '/:id/code',
  validate({ params: Joi.object({ id: Joi.string().guid().required() }) }),
  devicesController.issueCode,
);

module.exports = router;
