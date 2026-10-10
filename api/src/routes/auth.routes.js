// M1 FE-2: phone activation, sign-in, token refresh and sign-out.
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

// The activation code is 8 letters and digits; a dash or space between the
// two halves, and lower case, are accepted.
const activateSchema = Joi.object({
  username,
  password,
  activationCode: Joi.string().trim().pattern(/^[A-Za-z0-9]{4}[\s-]?[A-Za-z0-9]{4}$/).required(),
  deviceId: deviceId.required(),
  deviceModel: Joi.string().trim().max(100),
});

const refreshSchema = Joi.object({
  refreshToken: Joi.string().min(20).max(200).required(),
});

router.post('/login', validate({ body: loginSchema }), authController.login);
router.post('/activate', validate({ body: activateSchema }), authController.activate);
router.post('/refresh', validate({ body: refreshSchema }), authController.refresh);
router.post('/logout', validate({ body: refreshSchema }), authController.logout);

module.exports = router;
