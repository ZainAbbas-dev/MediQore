import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from './context';

// Auth guard: pages under this route need a signed-in supervisor or admin.
// Anyone else is sent to the login page and brought back after signing in.
export default function RequireAuth() {
  const { token } = useAuth();
  const location = useLocation();
  if (!token) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }
  return <Outlet />;
}
