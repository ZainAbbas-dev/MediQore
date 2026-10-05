// M10 FE-3: role permissions. The three roles are fixed (users.role). What each
// role may do is listed here once: every route checks it with requirePermission
// (middleware/auth.js), and GET /admin/roles shows this same list on the
// portal, so the page and the API cannot disagree.

const ROLES = {
  lhw: { label: 'LHW', description: 'Uses the Android app only. Sees and syncs the records of her own area.' },
  supervisor: {
    label: 'Supervisor',
    description: 'Uses the portal. Sees the records, LHWs and phones of the areas assigned to them.',
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
  'devices.approve': { roles: ['supervisor', 'admin'], label: 'Approve phones with one-time codes' },
  'accounts.manage': {
    roles: ['admin'],
    label: 'Create and manage LHW, supervisor and admin accounts, and reset passwords',
  },
  'geography.manage': { roles: ['admin'], label: 'Manage districts, tehsils, Union Councils and areas' },
  'facilities.manage': { roles: ['admin'], label: 'Manage hospitals and referral centres' },
  'audit.view': { roles: ['admin'], label: 'View the audit log' },
};

function rolesFor(permission) {
  const entry = PERMISSIONS[permission];
  if (!entry) throw new Error(`Unknown permission "${permission}"`);
  return entry.roles;
}

module.exports = { ROLES, PERMISSIONS, rolesFor };
