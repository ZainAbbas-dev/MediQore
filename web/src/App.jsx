// M10: supervisor and admin portal routes (P0-5 skeleton), with the Module 1
// admin screens: phone approvals (M1 FE-2) and LHW accounts (M1 FE-1, FE-3),
// and the registered women from Module 2.
import { Route, Routes } from 'react-router-dom';
import RequireAuth from './auth/RequireAuth';
import RequireRole from './auth/RequireRole';
import AppLayout from './layout/AppLayout';
import DashboardPage from './pages/DashboardPage';
import DevicesPage from './pages/DevicesPage';
import LhwsPage from './pages/LhwsPage';
import LoginPage from './pages/LoginPage';
import NotFoundPage from './pages/NotFoundPage';
import WomenPage from './pages/WomenPage';

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<RequireAuth />}>
        <Route element={<AppLayout />}>
          <Route index element={<DashboardPage />} />
          <Route element={<RequireRole roles={['admin', 'supervisor']} />}>
            <Route path="devices" element={<DevicesPage />} />
            <Route path="women" element={<WomenPage />} />
          </Route>
          <Route element={<RequireRole roles={['admin']} />}>
            <Route path="admin/lhws" element={<LhwsPage />} />
          </Route>
          <Route path="*" element={<NotFoundPage />} />
        </Route>
      </Route>
    </Routes>
  );
}
