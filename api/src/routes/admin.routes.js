// M1 FE-1, FE-3: LHW account management for admins.
const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requireRole } = require('../middleware/auth');
const adminController = require('../controllers/admin.controller');

const router = Router();

const uuid = Joi.string().guid();
const fullName = Joi.string().trim().min(2).max(100);
// Pakistani mobile numbers, typed with or without spaces and dashes.
const phone = Joi.string().trim().pattern(/^\+?[0-9][0-9 -]{6,18}[0-9]$/).allow('');

const idParams = Joi.object({ id: uuid.required() });

const listQuery = Joi.object({
  search: Joi.string().trim().max(100).allow(''),
  areaId: uuid,
  status: Joi.string().valid('active', 'inactive', 'all').default('all'),
});

const createBody = Joi.object({
  fullName: fullName.required(),
  areaId: uuid.required(),
  phone,
});

const updateBody = Joi.object({ fullName, areaId: uuid, phone }).min(1);

router.use(authenticate, requireRole('admin'));
router.get('/areas', adminController.listAreas);
router.get('/lhws', validate({ query: listQuery }), adminController.listLhws);
router.post('/lhws', validate({ body: createBody }), adminController.createLhw);
router.patch('/lhws/:id', validate({ params: idParams, body: updateBody }), adminController.updateLhw);
router.post('/lhws/:id/deactivate', validate({ params: idParams }), adminController.deactivateLhw);
router.post('/lhws/:id/activate', validate({ params: idParams }), adminController.activateLhw);
router.post('/lhws/:id/reset-password', validate({ params: idParams }), adminController.resetPassword);

module.exports = router;
