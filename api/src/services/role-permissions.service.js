const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { writeAudit } = require('./audit.service');
const { ROLES, PERMISSIONS, editable } = require('../auth/permissions');

// M10 FE-3, M1 FE-2: which role holds which permission. The defaults are in
// auth/permissions.js; role_permissions keeps the admin's changes. Every route
// asks allows() through requirePermission. The answer is cached for a few
// seconds and refreshed at once after a change in this process.

const CACHE_MS = 10 * 1000;
let cache = null; // { at, overrides: Map("role:permission" -> granted) }

async function overrides(client = db) {
  if (cache && Date.now() - cache.at < CACHE_MS) return cache.overrides;
  const { rows } = await client.query('SELECT role, permission, granted FROM role_permissions');
  cache = { at: Date.now(), overrides: new Map(rows.map((r) => [`${r.role}:${r.permission}`, r.granted])) };
  return cache.overrides;
}

function forget() {
  cache = null;
}

function holds(map, role, permission) {
  const fixedDefault = PERMISSIONS[permission].roles.includes(role);
  if (!editable(role, permission)) return fixedDefault;
  const choice = map.get(`${role}:${permission}`);
  return choice === undefined ? fixedDefault : choice;
}

async function allows(role, permission) {
  return holds(await overrides(), role, permission);
}

// GET /admin/roles: the roles, and for each permission who holds it and whether that can change.
async function matrix() {
  const map = await overrides();
  return {
    roles: Object.entries(ROLES).map(([id, role]) => ({ id, ...role })),
    permissions: Object.entries(PERMISSIONS).map(([id, permission]) => ({
      id,
      label: permission.label,
      defaultRoles: permission.roles,
      roles: Object.keys(ROLES).filter((role) => holds(map, role, id)),
      editableRoles: Object.keys(ROLES).filter((role) => editable(role, id)),
    })),
  };
}

// PUT /admin/roles/permissions: grants or removes permissions, each audited.
async function update(viewer, changes) {
  for (const { role, permission } of changes) {
    if (!PERMISSIONS[permission]) throw new AppError(400, 'VALIDATION_ERROR', `Unknown permission "${permission}"`);
    if (!editable(role, permission)) {
      throw new AppError(409, 'PERMISSION_FIXED', `The ${role} role's hold on "${permission}" cannot be changed`);
    }
  }
  await db.withTransaction(async (client) => {
    for (const { role, permission, granted } of changes) {
      await client.query(
        `INSERT INTO role_permissions (role, permission, granted, updated_by) VALUES ($1, $2, $3, $4)
         ON CONFLICT (role, permission) DO UPDATE SET granted = EXCLUDED.granted, updated_by = EXCLUDED.updated_by, updated_at = now()`,
        [role, permission, granted, viewer.id],
      );
      await writeAudit(client, {
        userId: viewer.id, action: 'edit', entityType: 'role_permissions', entityId: null,
        details: { role, permission, granted },
      });
    }
  });
  forget();
  return matrix();
}

module.exports = { allows, matrix, update, forget };
