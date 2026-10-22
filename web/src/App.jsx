// M10: supervisor and admin portal routes (P0-5 skeleton), with the Module 1
// screens: PIN reset codes (M1 FE-2) and LHW accounts with activation codes (M1 FE-1–3),
// the registered women from Module 2, the sync conflict queue (M3 FE-2) and the
// admin panel (M10 FE-3): accounts, areas, hospitals, roles and the audit log.
import { Route, Routes } from 'react-router-dom';
import RequireAuth from './auth/RequireAuth';
import RequirePermission from './auth/RequirePermission';
import AppLayout from './layout/AppLayout';
import AuditPage from './pages/AuditPage';
import ConflictsPage from './pages/ConflictsPage';
import DashboardPage from './pages/DashboardPage';
import FacilitiesPage from './pages/FacilitiesPage';
import GeographyPage from './pages/GeographyPage';
import LhwsPage from './pages/LhwsPage';
import LoginPage from './pages/LoginPage';
import NotFoundPage from './pages/NotFoundPage';
import PinResetPage from './pages/PinResetPage';
import RolesPage from './pages/RolesPage';
import StaffPage from './pages/StaffPage';
import WomenPage from './pages/WomenPage';

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<RequireAuth />}>
        <Route element={<AppLayout />}>
          <Route element={<RequirePermission permission="records.view" />}>
            <Route index element={<DashboardPage />} />
            <Route path="women" element={<WomenPage />} />
          </Route>
          <Route element={<RequirePermission permission="conflicts.resolve" />}>
            <Route path="conflicts" element={<ConflictsPage />} />
          </Route>
          <Route element={<RequirePermission permission="pin_reset.reply" />}>
            <Route path="pin-reset" element={<PinResetPage />} />
          </Route>
          <Route element={<RequirePermission permission="accounts.manage" />}>
            <Route path="admin/lhws" element={<LhwsPage />} />
          </Route>
          <Route element={<RequirePermission permission="staff.manage" />}>
            <Route path="admin/staff" element={<StaffPage />} />
          </Route>
          <Route element={<RequirePermission permission="geography.manage" />}>
            <Route path="admin/geography" element={<GeographyPage />} />
          </Route>
          <Route element={<RequirePermission permission="facilities.manage" />}>
            <Route path="admin/facilities" element={<FacilitiesPage />} />
          </Route>
          <Route element={<RequirePermission permission="roles.manage" />}>
            <Route path="admin/roles" element={<RolesPage />} />
          </Route>
          <Route element={<RequirePermission permission="audit.view" />}>
            <Route path="admin/audit" element={<AuditPage />} />
          </Route>
          <Route path="*" element={<NotFoundPage />} />
        </Route>
      </Route>
    </Routes>
  );
}
