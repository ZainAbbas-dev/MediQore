import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../auth/context';
import NavIcon from './NavIcon';

// Portal frame: sidebar navigation and the signed-in user. Each Module 10
// screen adds its link here as it is built. Administration (M10 FE-3) is for
// admins only; the API checks the same.
export default function AppLayout() {
  const { user, logout } = useAuth();

  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-mark" aria-hidden="true">
            +
          </span>
          MediQore
        </div>
        <nav aria-label="Main">
          <NavLink to="/" end>
            <NavIcon name="dashboard" />
            Dashboard
          </NavLink>
          <NavLink to="/women">
            <NavIcon name="women" />
            Registered women
          </NavLink>
          <NavLink to="/conflicts">
            <NavIcon name="conflicts" />
            Sync conflicts
          </NavLink>
          <NavLink to="/pin-reset">
            <NavIcon name="key" />
            PIN reset codes
          </NavLink>
        </nav>
        {user?.role === 'admin' && (
          <nav aria-label="Administration">
            <div className="nav-heading">Administration</div>
            <NavLink to="/admin/lhws">
              <NavIcon name="person" />
              LHW accounts
            </NavLink>
            <NavLink to="/admin/staff">
              <NavIcon name="staff" />
              Supervisors and admins
            </NavLink>
            <NavLink to="/admin/geography">
              <NavIcon name="map" />
              Geography
            </NavLink>
            <NavLink to="/admin/facilities">
              <NavIcon name="hospital" />
              Hospitals
            </NavLink>
            <NavLink to="/admin/roles">
              <NavIcon name="shield" />
              Roles
            </NavLink>
            <NavLink to="/admin/audit">
              <NavIcon name="history" />
              Audit log
            </NavLink>
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
