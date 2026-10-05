// M1 FE-1, FE-3: LHW account management. M10 FE-3: the rest of the admin panel:
// supervisor and admin accounts, the district > tehsil > Union Council > area
// structure, hospitals and referral centres, role permissions and the audit log.
const { Router } = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { authenticate, requirePermission } = require('../middleware/auth');
const adminController = require('../controllers/admin.controller');
const { LEVELS } = require('../services/geography.service');
const { ACTIONS } = require('../services/audit.service');

const router = Router();

const uuid = Joi.string().guid();
const fullName = Joi.string().trim().min(2).max(100);
// Pakistani mobile numbers, typed with or without spaces and dashes.
const phone = Joi.string().trim().pattern(/^\+?[0-9][0-9 -]{6,18}[0-9]$/).allow('');
const status = Joi.string().valid('active', 'inactive', 'all').default('all');

const idParams = Joi.object({ id: uuid.required() });

// LHW accounts (M1 FE-1, FE-3)

const lhwListQuery = Joi.object({
  search: Joi.string().trim().max(100).allow(''),
  areaId: uuid,
  status,
});

const lhwCreateBody = Joi.object({
  fullName: fullName.required(),
  areaId: uuid.required(),
  phone,
});

const lhwUpdateBody = Joi.object({ fullName, areaId: uuid, phone }).min(1);

// Supervisor and admin accounts (M10 FE-3). Usernames are chosen by the admin:
// lower-case letters, digits, dots, dashes and underscores.
const staffRole = Joi.string().valid('supervisor', 'admin');
const areaIds = Joi.array().items(uuid).max(200).unique();

const staffListQuery = Joi.object({
  search: Joi.string().trim().max(100).allow(''),
  role: staffRole,
  status,
});

const staffCreateBody = Joi.object({
  role: staffRole.required(),
  username: Joi.string().trim().lowercase().pattern(/^[a-z][a-z0-9._-]{2,31}$/).required(),
  fullName: fullName.required(),
  phone,
  areaIds: areaIds.default([]),
});

const staffUpdateBody = Joi.object({ role: staffRole, fullName, phone, areaIds }).min(1);

// Geography (M10 FE-3)

const unitName = Joi.string().trim().min(2).max(100);
const levelParams = Joi.object({ level: Joi.string().valid(...Object.keys(LEVELS)).required() });
const unitParams = levelParams.keys({ id: uuid.required() });
const unitCreateBody = Joi.object({ name: unitName.required(), parentId: uuid });
const unitRenameBody = Joi.object({ name: unitName.required() });

// Hospitals and referral centres (M10 FE-3)

const facilityFields = {
  name: Joi.string().trim().min(2).max(150),
  type: Joi.string().trim().max(100).allow(null, ''),
  districtId: uuid,
  areaId: uuid.allow(null),
  address: Joi.string().trim().max(300).allow(null, ''),
  phone: phone.allow(null),
  latitude: Joi.number().min(-90).max(90).precision(6).allow(null),
  longitude: Joi.number().min(-180).max(180).precision(6).allow(null),
};
// Empty text is stored as NULL.
const emptyToNull = (value) => Object.fromEntries(Object.entries(value).map(([k, v]) => [k, v === '' ? null : v]));
const facilityCreateBody = (typeRequired) => Joi.object({
  ...facilityFields,
  name: facilityFields.name.required(),
  districtId: uuid.required(),
  type: typeRequired ? Joi.string().trim().min(2).max(100).required() : facilityFields.type,
}).and('latitude', 'longitude').custom(emptyToNull);
const facilityUpdateBody = (typeRequired) => Joi.object({
  ...facilityFields,
  type: typeRequired ? Joi.string().trim().min(2).max(100) : facilityFields.type,
}).min(1).custom(emptyToNull);
const facilityListQuery = Joi.object({ districtId: uuid, search: Joi.string().trim().max(100).allow('') });

// Audit log (M10 FE-3)

const calendarDate = Joi.string().pattern(/^\d{4}-\d{2}-\d{2}$/);
const auditQuery = Joi.object({
  user: Joi.string().trim().max(100).allow(''),
  action: Joi.string().valid(...ACTIONS),
  entityType: Joi.string().trim().pattern(/^[a-z_]{1,40}$/),
  from: calendarDate,
  to: calendarDate,
  before: Joi.number().integer().min(1),
  limit: Joi.number().integer().min(1).max(200).default(50),
});

router.use(authenticate);

const accounts = requirePermission('accounts.manage');
router.get('/areas', accounts, adminController.listAreas);
router.get('/lhws', accounts, validate({ query: lhwListQuery }), adminController.listLhws);
router.post('/lhws', accounts, validate({ body: lhwCreateBody }), adminController.createLhw);
router.patch('/lhws/:id', accounts, validate({ params: idParams, body: lhwUpdateBody }), adminController.updateLhw);
router.post('/lhws/:id/deactivate', accounts, validate({ params: idParams }), adminController.deactivateLhw);
router.post('/lhws/:id/activate', accounts, validate({ params: idParams }), adminController.activateLhw);
router.post('/lhws/:id/reset-password', accounts, validate({ params: idParams }), adminController.resetPassword);

router.get('/staff', accounts, validate({ query: staffListQuery }), adminController.listStaff);
router.post('/staff', accounts, validate({ body: staffCreateBody }), adminController.createStaff);
router.patch('/staff/:id', accounts, validate({ params: idParams, body: staffUpdateBody }), adminController.updateStaff);
router.post('/staff/:id/deactivate', accounts, validate({ params: idParams }), adminController.deactivateStaff);
router.post('/staff/:id/activate', accounts, validate({ params: idParams }), adminController.activateStaff);
router.post('/staff/:id/reset-password', accounts, validate({ params: idParams }), adminController.resetStaffPassword);
router.get('/roles', accounts, adminController.listRoles);

const geography = requirePermission('geography.manage');
router.get('/geography', geography, adminController.geographyTree);
router.post('/geography/:level', geography, validate({ params: levelParams, body: unitCreateBody }), adminController.createUnit);
router.patch('/geography/:level/:id', geography, validate({ params: unitParams, body: unitRenameBody }), adminController.renameUnit);
router.delete('/geography/:level/:id', geography, validate({ params: unitParams }), adminController.deleteUnit);

const facilities = requirePermission('facilities.manage');
for (const [kind, typeRequired] of [['hospitals', false], ['referral-centres', true]]) {
  router.get(`/${kind}`, facilities, validate({ query: facilityListQuery }), adminController.listFacilities(kind));
  router.post(`/${kind}`, facilities, validate({ body: facilityCreateBody(typeRequired) }), adminController.createFacility(kind));
  router.patch(
    `/${kind}/:id`, facilities, validate({ params: idParams, body: facilityUpdateBody(typeRequired) }),
    adminController.updateFacility(kind),
  );
  router.delete(`/${kind}/:id`, facilities, validate({ params: idParams }), adminController.deleteFacility(kind));
}

router.get('/audit', requirePermission('audit.view'), validate({ query: auditQuery }), adminController.listAudit);

module.exports = router;
