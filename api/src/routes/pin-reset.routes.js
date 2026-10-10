// M1 FE-2: the supervisor's reply code for an LHW's offline PIN reset.
const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requirePermission } = require('../middleware/auth');
const pinResetController = require('../controllers/pin-reset.controller');

const router = Router();

// The phone shows its code as "483 917"; spaces are accepted.
const replyBody = Joi.object({
  lhwId: Joi.string().guid().required(),
  challenge: Joi.string().replace(/\s/g, '').pattern(/^\d{6}$/).required(),
});

router.post(
  '/reply-code',
  authenticate,
  requirePermission('pin_reset.reply'),
  validate({ body: replyBody }),
  pinResetController.replyCode,
);

module.exports = router;
