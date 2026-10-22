import { NavLink, Outlet } from 'react-router-dom';
import { can, useAuth } from '../auth/context';
import NavIcon from './NavIcon';

// Portal frame: sidebar navigation and the signed-in user. Each Module 10
// screen adds its link here as it is built. Each link shows only when the
// account's role holds the page's permission (M10 FE-3); the API checks the same.
const MAIN_LINKS = [
  { to: '/', icon: 'dashboard', label: 'Dashboard', permission: 'records.view', end: true },
  { to: '/women', icon: 'women', label: 'Registered women', permission: 'records.view' },
  { to: '/conflicts', icon: 'conflicts', label: 'Sync conflicts', permission: 'conflicts.resolve' },
  { to: '/pin-reset', icon: 'key', label: 'PIN reset codes', permission: 'pin_reset.reply' },
];

const ADMIN_LINKS = [
  { to: '/admin/lhws', icon: 'person', label: 'LHW accounts', permission: 'accounts.manage' },
  { to: '/admin/staff', icon: 'staff', label: 'Supervisors and admins', permission: 'accounts.manage' },
  { to: '/admin/geography', icon: 'map', label: 'Geography', permission: 'geography.manage' },
  { to: '/admin/facilities', icon: 'hospital', label: 'Hospitals', permission: 'facilities.manage' },
  { to: '/admin/roles', icon: 'shield', label: 'Roles', permission: 'roles.manage' },
  { to: '/admin/audit', icon: 'history', label: 'Audit log', permission: 'audit.view' },
];

const renderLink = (link) => (
  <NavLink key={link.to} to={link.to} end={link.end}>
    <NavIcon name={link.icon} />
    {link.label}
  </NavLink>
);

export default function AppLayout() {
  const { user, logout } = useAuth();
  const admin = ADMIN_LINKS.filter((link) => can(user, link.permission));

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
          {MAIN_LINKS.filter((link) => can(user, link.permission)).map(renderLink)}
        </nav>
        {admin.length > 0 && (
          <nav aria-label="Administration">
            <div className="nav-heading">Administration</div>
            {admin.map(renderLink)}
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
