import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../auth/context';

// Portal frame: sidebar navigation and the signed-in user. Each Module 10
// screen adds its link here as it is built. Administration (M10 FE-3) is for
// admins only; the API checks the same.
export default function AppLayout() {
  const { user, logout } = useAuth();

  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="brand">MediQore</div>
        <nav aria-label="Main">
          <NavLink to="/" end>
            Dashboard
          </NavLink>
          <NavLink to="/women">Registered women</NavLink>
          <NavLink to="/conflicts">Sync conflicts</NavLink>
          <NavLink to="/pin-reset">PIN reset codes</NavLink>
        </nav>
        {user?.role === 'admin' && (
          <nav aria-label="Administration">
            <div className="nav-heading">Administration</div>
            <NavLink to="/admin/lhws">LHW accounts</NavLink>
            <NavLink to="/admin/staff">Supervisors and admins</NavLink>
            <NavLink to="/admin/geography">Areas</NavLink>
            <NavLink to="/admin/facilities">Hospitals</NavLink>
            <NavLink to="/admin/roles">Roles</NavLink>
            <NavLink to="/admin/audit">Audit log</NavLink>
          </nav>
        )}
        <div className="sidebar-footer">
          <div className="user">
            <div>{user?.fullName}</div>
            <div className="role">{user?.role}</div>
          </div>
          <button type="button" className="link-button" onClick={logout}>
            Sign out
          </button>
        </div>
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
