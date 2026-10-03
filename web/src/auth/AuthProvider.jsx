// M10 / M1 FE-2: portal sign-in state (P0-5).
import { useCallback, useMemo, useState } from 'react';
import { apiRequest, ApiError } from '../api/client';
import { AuthContext, PORTAL_ROLES } from './context';

const STORAGE_KEY = 'mediqore.session';

function readStoredSession() {
  try {
    return JSON.parse(sessionStorage.getItem(STORAGE_KEY)) || null;
  } catch {
    return null;
  }
}

// Keeps the access token for this browser tab only (sessionStorage), so it is
// gone when the tab closes. Refresh tokens come with M1 FE-2 in Phase 1.
export default function AuthProvider({ children }) {
  const [session, setSession] = useState(readStoredSession);

  const login = useCallback(async (username, password) => {
    const result = await apiRequest('/auth/login', { method: 'POST', body: { username, password } });
    if (!PORTAL_ROLES.includes(result.user.role)) {
      throw new ApiError(403, 'PORTAL_ROLE', 'The portal is for supervisors and admins');
    }
    const next = { token: result.accessToken, user: result.user };
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify(next));
    setSession(next);
  }, []);

  const logout = useCallback(() => {
    sessionStorage.removeItem(STORAGE_KEY);
    setSession(null);
  }, []);

  const value = useMemo(
    () => ({ token: session?.token ?? null, user: session?.user ?? null, login, logout }),
    [session, login, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
