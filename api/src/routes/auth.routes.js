// M1 FE-2: sign-in, phone approval with a one-time code, token refresh and sign-out.
const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const authController = require('../controllers/auth.controller');

const router = Router();

const username = Joi.string().trim().min(1).max(100).required();
const password = Joi.string().min(1).max(200).required();
const deviceId = Joi.string().guid({ version: 'uuidv4' });

const loginSchema = Joi.object({
  username,
  password,
  deviceId, // the app's installation ID; required for LHWs
  deviceModel: Joi.string().trim().max(100),
});

const otpSchema = Joi.object({
  username,
  password,
  deviceId: deviceId.required(),
  code: Joi.string().pattern(/^\d{6}$/).required(),
});

const refreshSchema = Joi.object({
  refreshToken: Joi.string().min(20).max(200).required(),
});

router.post('/login', validate({ body: loginSchema }), authController.login);
router.post('/otp/verify', validate({ body: otpSchema }), authController.verifyOtp);
router.post('/refresh', validate({ body: refreshSchema }), authController.refresh);
router.post('/logout', validate({ body: refreshSchema }), authController.logout);

module.exports = router;
