// M10 FE-3, M1 FE-2: role permissions. The three roles are fixed (users.role).
// Every route checks a permission with requirePermission (middleware/auth.js).
// `roles` lists the roles that hold a permission by default; an admin can grant
// or remove it on the portal (role_permissions, services/role-permissions.service.js),
// except where the choice is fixed:
//   - LHWs use only the app: they hold `sync` and nothing else, and no portal role syncs;
//   - admins always keep `roles.manage`, so the system can never lock itself out;
//   - only admins manage roles, supervisor and admin accounts and the geography:
//     none of these is limited to an area, and a supervisor holding one could
//     give themselves more. The other administration permissions a supervisor
//     may be given apply to their own areas only (services/scope.service.js).

const ROLES = {
  lhw: { label: 'LHW', description: 'Uses the Android app only. Sees and syncs the records of her own area.' },
  supervisor: {
    label: 'Supervisor',
    description: 'Uses the portal. Sees the records and LHWs of the areas assigned to them.',
  },
  admin: { label: 'Admin', description: 'Uses the portal. Sees every area and manages the system.' },
};

const PERMISSIONS = {
  sync: { roles: ['lhw'], label: 'Send and receive records from the LHW app (sync)' },
  'records.view': {
    roles: ['supervisor', 'admin'],
    label: 'View the dashboard, the household map, registered women, visits and LHW activity',
  },
  'conflicts.resolve': { roles: ['supervisor', 'admin'], label: 'Review and decide sync conflicts' },
  'pin_reset.reply': {
    roles: ['supervisor', 'admin'],
    label: 'Give an LHW the reply code that resets a forgotten PIN on her phone',
  },
  'accounts.manage': {
    roles: ['admin'],
    label: 'Create and manage LHW accounts, give activation codes and reset passwords',
  },
  'staff.manage': { roles: ['admin'], label: 'Create and manage supervisor and admin accounts' },
  'geography.manage': { roles: ['admin'], label: 'Manage districts, tehsils, Union Councils and areas' },
  'facilities.manage': { roles: ['admin'], label: 'Manage hospitals and referral centres' },
  'audit.view': { roles: ['admin'], label: 'View the audit log' },
  'roles.manage': { roles: ['admin'], label: 'Choose which role holds which permission' },
};

// Permissions only admins hold: they are not limited to areas.
const ADMIN_ONLY = ['roles.manage', 'staff.manage', 'geography.manage'];

// Whether an admin may change this role's hold on this permission.
function editable(role, permission) {
  if (role === 'lhw' || permission === 'sync') return false;
  return !ADMIN_ONLY.includes(permission);
}

function rolesFor(permission) {
  const entry = PERMISSIONS[permission];
  if (!entry) throw new Error(`Unknown permission "${permission}"`);
  return entry.roles;
}

module.exports = { ROLES, PERMISSIONS, rolesFor, editable };
