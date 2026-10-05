import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import { adminSession, mockApi, renderApp, supervisorSession } from './helpers';

jest.mock('../src/components/AreaMap', () => function AreaMapStub() {
  return <div data-testid="area-map" />;
});

const areas = [
  { id: 'a1', name: 'Area 0101-1', unionCouncil: 'UC 0101', tehsil: 'Rawalpindi', district: 'Rawalpindi' },
  { id: 'a2', name: 'Area 0201-1', unionCouncil: 'UC 0201', tehsil: 'Attock', district: 'Attock' },
];

const supervisor = {
  id: 's1', role: 'supervisor', username: 'sup.rwp', fullName: 'Nadia Supervisor', phone: null, isActive: true,
  lastLoginAt: null, createdAt: '2026-10-01T00:00:00.000Z', areas: [areas[0]],
};
const me = {
  id: adminSession.user.id, role: 'admin', username: 'admin.demo', fullName: 'Demo Admin', phone: null, isActive: true,
  lastLoginAt: '2026-10-04T08:00:00.000Z', createdAt: '2026-10-01T00:00:00.000Z', areas: [],
};

const postBody = (fetchMock, path) => {
  const call = fetchMock.mock.calls.find(([url, options]) => url.endsWith(path) && options.method === 'POST');
  return JSON.parse(call[1].body);
};

describe('supervisors and admins (M10 FE-3)', () => {
  it('lists the portal accounts with role and areas; your own account cannot be deactivated', async () => {
    mockApi({ 'GET /admin/staff': [200, { staff: [me, supervisor] }], 'GET /admin/areas': [200, { areas }] });
    renderApp('/admin/staff', { session: adminSession });

    const row = (await screen.findByText('sup.rwp')).closest('tr');
    expect(row).toHaveTextContent('Supervisor');
    expect(row).toHaveTextContent('Area 0101-1');
    const mine = screen.getByText('admin.demo').closest('tr');
    expect(mine).toHaveTextContent('All areas');
    expect(within(mine).getByText('you')).toBeInTheDocument();
    expect(within(mine).queryByRole('button', { name: /Deactivate/ })).not.toBeInTheDocument();
    expect(within(row).getByRole('button', { name: 'Deactivate sup.rwp' })).toBeInTheDocument();
  });

  it('creates a supervisor with chosen areas and shows the password once', async () => {
    const fetchMock = mockApi({
      'GET /admin/staff': [200, { staff: [me] }],
      'GET /admin/areas': [200, { areas }],
      'POST /admin/staff': [201, { staff: supervisor, credentials: { username: 'sup.rwp', password: 'Pa55wordXy' } }],
    });
    renderApp('/admin/staff', { session: adminSession });
    fireEvent.click(await screen.findByRole('button', { name: 'Add account' }));
    const dialog = screen.getByRole('dialog', { name: 'Add supervisor or admin' });

    fireEvent.change(within(dialog).getByLabelText('Username'), { target: { value: 'Sup.Rwp' } });
    fireEvent.change(within(dialog).getByLabelText('Full name'), { target: { value: 'Nadia Supervisor' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Create account' }));
    expect(await within(dialog).findByRole('alert')).toHaveTextContent('Choose at least one area');

    fireEvent.change(within(dialog).getByLabelText('Find an area'), { target: { value: 'rawal' } });
    expect(within(dialog).queryByText(/Attock/)).not.toBeInTheDocument();
    fireEvent.click(within(dialog).getByLabelText(/Area 0101-1/));
    fireEvent.click(within(dialog).getByRole('button', { name: 'Create account' }));

    const created = await screen.findByRole('dialog', { name: 'Account created' });
    expect(within(created).getByText('Pa55wordXy')).toBeInTheDocument();
    expect(postBody(fetchMock, '/admin/staff')).toEqual({
      role: 'supervisor', username: 'sup.rwp', fullName: 'Nadia Supervisor', areaIds: ['a1'],
    });
    fireEvent.click(within(created).getByRole('button', { name: 'Done' }));
    expect(screen.queryByText('Pa55wordXy')).not.toBeInTheDocument();
  });

  it('shows the API\'s refusal, for example a taken username', async () => {
    mockApi({
      'GET /admin/staff': [200, { staff: [] }],
      'GET /admin/areas': [200, { areas }],
      'POST /admin/staff': [409, { error: { code: 'USERNAME_TAKEN', message: 'This username is already used' } }],
    });
    renderApp('/admin/staff', { session: adminSession });
    fireEvent.click(await screen.findByRole('button', { name: 'Add account' }));
    const dialog = screen.getByRole('dialog');
    fireEvent.change(within(dialog).getByLabelText('Role'), { target: { value: 'admin' } });
    fireEvent.change(within(dialog).getByLabelText('Username'), { target: { value: 'admin.two' } });
    fireEvent.change(within(dialog).getByLabelText('Full name'), { target: { value: 'Second Admin' } });
    expect(within(dialog).queryByText('Areas (0 chosen)')).not.toBeInTheDocument();
    fireEvent.click(within(dialog).getByRole('button', { name: 'Create account' }));

    expect(await within(dialog).findByRole('alert')).toHaveTextContent('This username is already used');
  });

  it('does not let you change the role of your own account', async () => {
    mockApi({ 'GET /admin/staff': [200, { staff: [me] }], 'GET /admin/areas': [200, { areas }] });
    renderApp('/admin/staff', { session: adminSession });
    fireEvent.click(await screen.findByRole('button', { name: 'Edit admin.demo' }));

    expect(within(screen.getByRole('dialog')).getByLabelText('Role')).toBeDisabled();
  });
});

const tree = {
  districts: [{
    id: 'd1', name: 'Rawalpindi', tehsils: [{
      id: 't1', name: 'Rawalpindi Tehsil', unionCouncils: [{
        id: 'uc1', name: 'UC 0101', areas: [{ id: 'a1', name: 'Area 0101-1', lhws: 2, supervisors: 1 }],
      }],
    }],
  }],
};

describe('areas (M10 FE-3)', () => {
  it('drills down from district to area, with LHW and supervisor counts', async () => {
    mockApi({ 'GET /admin/geography': [200, tree] });
    renderApp('/admin/geography', { session: adminSession });

    fireEvent.click(await screen.findByRole('button', { name: 'Rawalpindi' }));
    fireEvent.click(screen.getByRole('button', { name: 'Rawalpindi Tehsil' }));
    fireEvent.click(screen.getByRole('button', { name: 'UC 0101' }));

    const areasColumn = screen.getByRole('region', { name: 'Areas' });
    expect(areasColumn).toHaveTextContent('in UC 0101');
    expect(areasColumn).toHaveTextContent('Area 0101-1 · 2 LHWs, 1 supervisor');
  });

  it('adds a unit under the chosen parent', async () => {
    const fetchMock = mockApi({
      'GET /admin/geography': [200, tree],
      'POST /admin/geography/tehsils': [201, { unit: { id: 't2', name: 'Gujar Khan', parentId: 'd1' } }],
    });
    renderApp('/admin/geography', { session: adminSession });
    fireEvent.click(await screen.findByRole('button', { name: 'Rawalpindi' }));

    const tehsils = screen.getByRole('region', { name: 'Tehsils' });
    fireEvent.change(within(tehsils).getByLabelText('New tehsil'), { target: { value: 'Gujar Khan' } });
    fireEvent.click(within(tehsils).getByRole('button', { name: 'Add' }));

    expect(await screen.findByRole('status')).toHaveTextContent('Gujar Khan added.');
    expect(postBody(fetchMock, '/admin/geography/tehsils')).toEqual({ name: 'Gujar Khan', parentId: 'd1' });
  });

  it('explains why a unit in use cannot be deleted', async () => {
    mockApi({
      'GET /admin/geography': [200, tree],
      'DELETE /admin/geography/districts/d1': [409, {
        error: { code: 'IN_USE', message: 'This district is still used by 1 tehsils', details: { uses: ['1 tehsils'] } },
      }],
    });
    renderApp('/admin/geography', { session: adminSession });
    fireEvent.click(await screen.findByRole('button', { name: 'Delete Rawalpindi' }));
    fireEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Delete' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('This district is still used by 1 tehsils');
  });

  it('renames a unit', async () => {
    const fetchMock = mockApi({
      'GET /admin/geography': [200, tree],
      'PATCH /admin/geography/districts/d1': [200, { unit: { id: 'd1', name: 'Rawalpindi District', parentId: null } }],
    });
    renderApp('/admin/geography', { session: adminSession });
    fireEvent.click(await screen.findByRole('button', { name: 'Rename Rawalpindi' }));
    fireEvent.change(screen.getByLabelText('Name'), { target: { value: 'Rawalpindi District' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));

    expect(await screen.findByRole('status')).toHaveTextContent('Renamed to Rawalpindi District.');
    const patch = fetchMock.mock.calls.find(([, options]) => options.method === 'PATCH');
    expect(JSON.parse(patch[1].body)).toEqual({ name: 'Rawalpindi District' });
  });
});

const hospital = {
  id: 'h1', name: 'DHQ Hospital Rawalpindi', type: 'DHQ', address: 'Murree Road', phone: '051 1234567', latitude: 33.6,
  longitude: 73.05, district: { id: 'd1', name: 'Rawalpindi' }, area: null, serverSeq: 9, updatedAt: '2026-10-04T08:00:00.000Z',
};

describe('hospitals and referral centres (M10 FE-3)', () => {
  it('lists hospitals and switches to referral centres', async () => {
    mockApi({
      'GET /admin/geography': [200, tree],
      'GET /admin/hospitals': [200, { facilities: [hospital] }],
      'GET /admin/referral-centres': [200, { facilities: [] }],
    });
    renderApp('/admin/facilities', { session: adminSession });

    const row = (await screen.findByText('DHQ Hospital Rawalpindi')).closest('tr');
    expect(row).toHaveTextContent('Whole district');
    expect(row).toHaveTextContent('33.6, 73.05');

    fireEvent.click(screen.getByRole('tab', { name: 'Referral centres' }));
    expect(await screen.findByText('No referral centres yet.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Add referral centre' })).toBeInTheDocument();
  });

  it('adds a hospital in a district and one of its areas, with GPS', async () => {
    const fetchMock = mockApi({
      'GET /admin/geography': [200, tree],
      'GET /admin/hospitals': [200, { facilities: [] }],
      'POST /admin/hospitals': [201, { facility: hospital }],
    });
    renderApp('/admin/facilities', { session: adminSession });
    fireEvent.click(await screen.findByRole('button', { name: 'Add hospital' }));
    const dialog = screen.getByRole('dialog', { name: 'Add hospital' });
    await within(dialog).findByRole('option', { name: 'Rawalpindi' });

    fireEvent.change(within(dialog).getByLabelText('Name'), { target: { value: 'THQ Gujar Khan' } });
    fireEvent.change(within(dialog).getByLabelText('District'), { target: { value: 'd1' } });
    fireEvent.change(within(dialog).getByLabelText('Area (optional)'), { target: { value: 'a1' } });
    fireEvent.change(within(dialog).getByLabelText('Latitude (optional)'), { target: { value: '33.25' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Add hospital' }));
    expect(within(dialog).getByRole('alert')).toHaveTextContent('Give both latitude and longitude');

    fireEvent.change(within(dialog).getByLabelText('Longitude (optional)'), { target: { value: '73.3' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Add hospital' }));

    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(postBody(fetchMock, '/admin/hospitals')).toEqual({
      name: 'THQ Gujar Khan', type: null, districtId: 'd1', areaId: 'a1', address: null, phone: null, latitude: 33.25, longitude: 73.3,
    });
  });
});

describe('roles and the audit log (M10 FE-3)', () => {
  it('shows what each fixed role may do', async () => {
    mockApi({
      'GET /admin/roles': [200, {
        roles: [
          { id: 'lhw', label: 'LHW', description: 'App only' },
          { id: 'supervisor', label: 'Supervisor', description: 'Their areas' },
          { id: 'admin', label: 'Admin', description: 'Everything' },
        ],
        permissions: [{ id: 'audit.view', label: 'View the audit log', roles: ['admin'] }],
      }],
    });
    renderApp('/admin/roles', { session: adminSession });

    const row = (await screen.findByRole('rowheader', { name: 'View the audit log' })).closest('tr');
    expect(within(row).getByLabelText('Admin: allowed')).toHaveTextContent('✓');
    expect(within(row).getByLabelText('Supervisor: not allowed')).toHaveTextContent('–');
  });

  const entry = (id, extra = {}) => ({
    id, occurredAt: '2026-10-04T08:00:00.000Z', action: 'edit', entityType: 'users', entityId: '7c6b5a49-3827-4e16-9d0c-bafedcba9876',
    entityLabel: 'LHW-00007', deviceId: null, details: { changes: { fullName: { from: 'Sana', to: 'Sana Iqbal' } } },
    user: { id: 'u1', username: 'admin.demo', fullName: 'Demo Admin', role: 'admin' }, ...extra,
  });

  it('lists who did what, with the changes, filters by action and loads older entries', async () => {
    const fetchMock = mockApi({
      'GET /admin/audit': [200, { entries: [entry(12)], nextBefore: 12, actions: ['create', 'edit', 'login'], entityTypes: ['users'] }],
      'GET /admin/audit?before=12': [200, {
        entries: [entry(11, { action: 'login', user: null, entityLabel: null, details: { outcome: 'wrong_password' } })],
        nextBefore: null, actions: [], entityTypes: [],
      }],
      'GET /admin/audit?action=login': [200, { entries: [], nextBefore: null, actions: ['create', 'edit', 'login'], entityTypes: ['users'] }],
    });
    renderApp('/admin/audit', { session: adminSession });

    const row = (await screen.findByText('fullName: Sana → Sana Iqbal')).closest('tr');
    expect(row).toHaveTextContent('admin.demo');
    expect(row).toHaveTextContent('Changed');
    expect(row).toHaveTextContent('LHW-00007');

    fireEvent.click(screen.getByRole('button', { name: 'Show older entries' }));
    expect(await screen.findByText('outcome: wrong_password')).toBeInTheDocument();
    expect(screen.getByText('Unknown')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Show older entries' })).not.toBeInTheDocument();

    fireEvent.change(screen.getByLabelText('Action'), { target: { value: 'login' } });
    expect(await screen.findByText('Nothing in the log matches.')).toBeInTheDocument();
    expect(fetchMock.mock.calls.some(([url]) => url.endsWith('/admin/audit?action=login'))).toBe(true);
  });
});

describe('administration in the sidebar', () => {
  it('is shown to admins only, and its pages are closed to supervisors', async () => {
    mockApi({
      'GET /households': [200, { households: [] }],
      'GET /dashboard/summary': [200, { registeredWomen: 0, visitsThisWeek: 0, pendingConflicts: 0 }],
    });
    const { unmount } = renderApp('/', { session: adminSession });
    const admin = await screen.findByRole('navigation', { name: 'Administration' });
    for (const name of ['LHW accounts', 'Supervisors and admins', 'Areas', 'Hospitals', 'Roles', 'Audit log']) {
      expect(within(admin).getByRole('link', { name })).toBeInTheDocument();
    }
    unmount();
    sessionStorage.clear();

    renderApp('/admin/audit', { session: supervisorSession });
    expect(await screen.findByRole('heading', { name: 'Not available' })).toBeInTheDocument();
    expect(screen.queryByRole('navigation', { name: 'Administration' })).not.toBeInTheDocument();
  });
});
