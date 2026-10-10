const lhwsService = require('../services/lhws.service');
const staffService = require('../services/staff.service');
const geographyService = require('../services/geography.service');
const facilitiesService = require('../services/facilities.service');
const auditService = require('../services/audit.service');
const { ROLES, PERMISSIONS } = require('../auth/permissions');

// M1 FE-1, FE-3: LHW accounts.

async function listAreas(req, res) {
  res.json(await lhwsService.listAreas());
}

async function listLhws(req, res) {
  res.json(await lhwsService.list(req.query));
}

async function createLhw(req, res) {
  res.status(201).json(await lhwsService.create(req.user, req.body));
}

async function updateLhw(req, res) {
  res.json(await lhwsService.update(req.user, req.params.id, req.body));
}

async function deactivateLhw(req, res) {
  res.json(await lhwsService.setActive(req.user, req.params.id, false));
}

async function activateLhw(req, res) {
  res.json(await lhwsService.setActive(req.user, req.params.id, true));
}

async function resetPassword(req, res) {
  res.json(await lhwsService.resetPassword(req.user, req.params.id));
}

async function issueActivationCode(req, res) {
  res.status(201).json(await lhwsService.issueActivationCode(req.user, req.params.id));
}

// M10 FE-3: supervisor and admin accounts.

async function listStaff(req, res) {
  res.json(await staffService.list(req.query));
}

async function createStaff(req, res) {
  res.status(201).json(await staffService.create(req.user, req.body));
}

async function updateStaff(req, res) {
  res.json(await staffService.update(req.user, req.params.id, req.body));
}

async function deactivateStaff(req, res) {
  res.json(await staffService.setActive(req.user, req.params.id, false));
}

async function activateStaff(req, res) {
  res.json(await staffService.setActive(req.user, req.params.id, true));
}

async function resetStaffPassword(req, res) {
  res.json(await staffService.resetPassword(req.user, req.params.id));
}

// M10 FE-3: district, tehsil, Union Council and area structure.

async function geographyTree(req, res) {
  res.json(await geographyService.tree());
}

async function createUnit(req, res) {
  res.status(201).json(await geographyService.create(req.user, req.params.level, req.body));
}

async function renameUnit(req, res) {
  res.json(await geographyService.rename(req.user, req.params.level, req.params.id, req.body));
}

async function deleteUnit(req, res) {
  await geographyService.remove(req.user, req.params.level, req.params.id);
  res.status(204).end();
}

// M10 FE-3: hospitals and referral centres. Each handler is made for one kind
// ('hospitals' or 'referral-centres', see facilities.service KINDS).

const listFacilities = (kind) => async (req, res) => {
  res.json(await facilitiesService.list(kind, req.query));
};

const createFacility = (kind) => async (req, res) => {
  res.status(201).json(await facilitiesService.create(req.user, kind, req.body));
};

const updateFacility = (kind) => async (req, res) => {
  res.json(await facilitiesService.update(req.user, kind, req.params.id, req.body));
};

const deleteFacility = (kind) => async (req, res) => {
  await facilitiesService.remove(req.user, kind, req.params.id);
  res.status(204).end();
};

// M10 FE-3: the audit log viewer and role permissions.

async function listAudit(req, res) {
  res.json({ ...(await auditService.list(req.query)), actions: auditService.ACTIONS, entityTypes: await auditService.entityTypes() });
}

function listRoles(req, res) {
  res.json({
    roles: Object.entries(ROLES).map(([id, role]) => ({ id, ...role })),
    permissions: Object.entries(PERMISSIONS).map(([id, permission]) => ({ id, ...permission })),
  });
}

module.exports = {
  listAreas, listLhws, createLhw, updateLhw, deactivateLhw, activateLhw, resetPassword,
  issueActivationCode,
  listStaff, createStaff, updateStaff, deactivateStaff, activateStaff, resetStaffPassword,
  geographyTree, createUnit, renameUnit, deleteUnit,
  listFacilities, createFacility, updateFacility, deleteFacility,
  listAudit, listRoles,
};
