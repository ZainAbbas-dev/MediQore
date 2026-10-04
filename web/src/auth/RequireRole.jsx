import { Outlet } from 'react-router-dom';
import { useAuth } from './context';

// Shows the child routes only to the given roles (role checks also run on the API).
export default function RequireRole({ roles }) {
  const { user } = useAuth();
  if (!roles.includes(user?.role)) {
    return (
      <>
        <h1>Not available</h1>
        <p className="muted">This page is for {roles.join(' and ')} accounts.</p>
      </>
    );
  }
  return <Outlet />;
}
