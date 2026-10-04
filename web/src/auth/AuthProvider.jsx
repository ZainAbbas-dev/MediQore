// M10 / M1 FE-2: portal sign-in state (P0-5), with refresh tokens (Phase 1).
import { useCallback, useMemo, useRef, useState } from 'react';
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

function storeSession(session) {
  if (session) sessionStorage.setItem(STORAGE_KEY, JSON.stringify(session));
  else sessionStorage.removeItem(STORAGE_KEY);
}

// Keeps the tokens for this browser tab only (sessionStorage), so they are
// gone when the tab closes. `request()` adds the access token; when the API
// answers 401 it swaps the refresh token for a new pair once and retries.
// A failed refresh, or a deactivated account, signs the user out.
export default function AuthProvider({ children }) {
  const [session, setSession] = useState(readStoredSession);
  const sessionRef = useRef(session);
  const refreshing = useRef(null);

  const update = useCallback((next) => {
    sessionRef.current = next;
    storeSession(next);
    setSession(next);
  }, []);

  const login = useCallback(async (username, password) => {
    const result = await apiRequest('/auth/login', { method: 'POST', body: { username, password } });
    if (!PORTAL_ROLES.includes(result.user.role)) {
      throw new ApiError(403, 'PORTAL_ROLE', 'The portal is for supervisors and admins');
    }
    update({ token: result.accessToken, refreshToken: result.refreshToken, user: result.user });
  }, [update]);

  const logout = useCallback(() => {
    const refreshToken = sessionRef.current?.refreshToken;
    update(null);
    if (refreshToken) {
      apiRequest('/auth/logout', { method: 'POST', body: { refreshToken } }).catch(() => {});
    }
  }, [update]);

  // One refresh at a time, shared by requests that fail together.
  const refresh = useCallback(() => {
    if (!refreshing.current) {
      const refreshToken = sessionRef.current?.refreshToken;
      refreshing.current = (refreshToken
        ? apiRequest('/auth/refresh', { method: 'POST', body: { refreshToken } })
          .then((result) => {
            const next = { token: result.accessToken, refreshToken: result.refreshToken, user: result.user };
            update(next);
            return next;
          })
          .catch(() => null)
        : Promise.resolve(null)
      ).finally(() => {
        refreshing.current = null;
      });
    }
    return refreshing.current;
  }, [update]);

  const request = useCallback(async (path, options = {}) => {
    try {
      return await apiRequest(path, { ...options, token: sessionRef.current?.token });
    } catch (error) {
      if (error.code === 'ACCOUNT_INACTIVE') {
        update(null);
        throw error;
      }
      if (error.status !== 401) throw error;
      const next = await refresh();
      if (!next) {
        update(null);
        throw error;
      }
      return apiRequest(path, { ...options, token: next.token });
    }
  }, [refresh, update]);

  const value = useMemo(
    () => ({ token: session?.token ?? null, user: session?.user ?? null, login, logout, request }),
    [session, login, logout, request],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
