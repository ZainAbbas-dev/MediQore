import { createContext, useContext } from 'react';

// The portal is for supervisors and admins; LHWs use the mobile app.
export const PORTAL_ROLES = ['supervisor', 'admin'];

// { token, user, login(username, password), logout() }, provided by <AuthProvider>.
export const AuthContext = createContext(null);

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth must be used inside <AuthProvider>');
  return value;
}
