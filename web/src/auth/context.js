import { createContext, useContext } from 'react';

// The portal is for supervisors and admins; LHWs use the mobile app.
export const PORTAL_ROLES = ['supervisor', 'admin'];

// What each portal role holds before an admin changes it (api/src/auth/permissions.js).
// A session saved before the API sent `user.permissions` falls back to these.
const ROLE_DEFAULTS = {
  supervisor: ['records.view', 'conflicts.resolve', 'pin_reset.reply'],
  admin: [
    'records.view', 'conflicts.resolve', 'pin_reset.reply', 'accounts.manage', 'staff.manage', 'geography.manage',
    'facilities.manage', 'audit.view', 'roles.manage',
  ],
};

// Whether the signed-in account may open the pages behind `permission` (M10 FE-3).
export function can(user, permission) {
  return (user?.permissions ?? ROLE_DEFAULTS[user?.role] ?? []).includes(permission);
}

// { token, user, login(username, password), logout(), request(path, options) },
// provided by <AuthProvider>. Pages call the API through request(), which adds
// the token and refreshes it when it expires.
export const AuthContext = createContext(null);

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth must be used inside <AuthProvider>');
  return value;
}
