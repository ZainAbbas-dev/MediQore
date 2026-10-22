import { Outlet } from 'react-router-dom';
import { can, useAuth } from './context';

// Shows the child routes only to accounts whose role holds `permission`
// (M10 FE-3; the API checks it on every request too).
export default function RequirePermission({ permission }) {
  const { user } = useAuth();
  if (!can(user, permission)) {
    return (
      <>
        <h1>Not available</h1>
        <p className="muted">Your role does not have access to this page. An admin can change that under Roles.</p>
      </>
    );
  }
  return <Outlet />;
}
