import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import { adminSession, mockApi, renderApp } from './helpers';

jest.mock('../src/components/AreaMap', () => function AreaMapStub() {
  return <div data-testid="area-map" />;
});

const areas = [
  { id: 'a1', name: 'Area 0101-1', unionCouncil: 'UC-0101', tehsil: 'Rawalpindi Tehsil 1', district: 'Rawalpindi [syn]' },
  { id: 'a2', name: 'Area 0101-2', unionCouncil: 'UC-0101', tehsil: 'Rawalpindi Tehsil 1', district: 'Rawalpindi [syn]' },
];

function lhw(overrides = {}) {
  return {
    id: 'l1',
    lhwCode: 'LHW-00001',
    username: 'LHW-00001',
    fullName: 'Ayesha Khan',
    phone: null,
    isActive: true,
    lastLoginAt: null,
    area: {
      id: 'a1', name: 'Area 0101-1',
      unionCouncil: { id: 'u', name: 'UC-0101' }, tehsil: { id: 't', name: 'Rawalpindi Tehsil 1' }, district: { id: 'd', name: 'Rawalpindi [syn]' },
    },
    devices: { approved: 1, pending: 0 },
    ...overrides,
  };
}

const bodyOf = (fetchMock, method, suffix) => {
  const call = fetchMock.mock.calls.find(([url, o]) => url.endsWith(suffix) && o.method === method);
  return call && JSON.parse(call[1].body ?? '{}');
};

describe('LHW accounts (M1 FE-1, FE-3)', () => {
  it('lists LHWs with their area, status and phones', async () => {
    mockApi({
      'GET /admin/lhws': [200, { lhws: [lhw(), lhw({ id: 'l2', lhwCode: 'LHW-00002', fullName: 'Bushra Ali', isActive: false, devices: { approved: 0, pending: 1 } })] }],
      'GET /admin/areas': [200, { areas }],
    });
    renderApp('/admin/lhws', { session: adminSession });

    const first = (await screen.findByText('Ayesha Khan')).closest('tr');
    expect(within(first).getByText('LHW-00001')).toBeInTheDocument();
    expect(within(first).getByText('Active')).toBeInTheDocument();
    const second = screen.getByText('Bushra Ali').closest('tr');
    expect(within(second).getByText('Deactivated')).toBeInTheDocument();
    expect(within(second).getByText(/1 waiting/)).toBeInTheDocument();
    expect(within(second).getByRole('button', { name: 'Activate LHW-00002' })).toBeInTheDocument();
  });

  it('creates an LHW and shows the issued LHW ID and password once', async () => {
    const created = lhw({ id: 'l9', lhwCode: 'LHW-00009', fullName: 'Hina Shah', devices: { approved: 0, pending: 0 } });
    const fetchMock = mockApi({
      'GET /admin/lhws': [200, { lhws: [] }],
      'GET /admin/areas': [200, { areas }],
      'POST /admin/lhws': [201, { lhw: created, credentials: { username: 'LHW-00009', password: 'Xk7mPq2Rtz' } }],
    });
    renderApp('/admin/lhws', { session: adminSession });

    fireEvent.click(await screen.findByRole('button', { name: 'Add LHW' }));
    const dialog = screen.getByRole('dialog', { name: 'Add LHW' });
    fireEvent.change(within(dialog).getByLabelText('Full name'), { target: { value: 'Hina Shah' } });
    await waitFor(() => expect(within(dialog).getAllByRole('option')).toHaveLength(3));
    fireEvent.change(within(dialog).getByLabelText('Area'), { target: { value: 'a2' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Create LHW' }));

    const done = await screen.findByRole('dialog', { name: 'LHW created' });
    expect(within(done).getByText('LHW-00009')).toBeInTheDocument();
    expect(within(done).getByText('Xk7mPq2Rtz')).toBeInTheDocument();
    expect(bodyOf(fetchMock, 'POST', '/admin/lhws')).toEqual({ fullName: 'Hina Shah', areaId: 'a2' });

    fireEvent.click(within(done).getByRole('button', { name: 'Done' }));
    expect(screen.queryByText('Xk7mPq2Rtz')).not.toBeInTheDocument();
  });

  it('warns to sync before an area change and saves the edit', async () => {
    const fetchMock = mockApi({
      'GET /admin/lhws': [200, { lhws: [lhw()] }],
      'GET /admin/areas': [200, { areas }],
      'PATCH /admin/lhws/l1': [200, { lhw: lhw({ area: { ...lhw().area, id: 'a2', name: 'Area 0101-2' } }) }],
    });
    renderApp('/admin/lhws', { session: adminSession });

    fireEvent.click(await screen.findByRole('button', { name: 'Edit LHW-00001' }));
    const dialog = screen.getByRole('dialog', { name: 'Edit LHW-00001' });
    await waitFor(() => expect(within(dialog).getAllByRole('option')).toHaveLength(3));
    fireEvent.change(within(dialog).getByLabelText('Area'), { target: { value: 'a2' } });

    expect(within(dialog).getByText(/still go to the old area when they arrive/)).toBeInTheDocument();
    fireEvent.click(within(dialog).getByRole('button', { name: 'Save changes' }));

    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(bodyOf(fetchMock, 'PATCH', '/admin/lhws/l1')).toEqual({ fullName: 'Ayesha Khan', phone: '', areaId: 'a2' });
  });

  it('deactivates an LHW after confirmation', async () => {
    const fetchMock = mockApi({
      'GET /admin/lhws': [200, { lhws: [lhw()] }],
      'GET /admin/areas': [200, { areas }],
      'POST /admin/lhws/l1/deactivate': [200, { lhw: lhw({ isActive: false }) }],
    });
    renderApp('/admin/lhws', { session: adminSession });

    fireEvent.click(await screen.findByRole('button', { name: 'Deactivate LHW-00001' }));
    const dialog = screen.getByRole('dialog', { name: 'Deactivate LHW-00001?' });
    expect(within(dialog).getByText(/will not be able to sign in or sync/)).toBeInTheDocument();
    fireEvent.click(within(dialog).getByRole('button', { name: 'Deactivate' }));

    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(fetchMock.mock.calls.some(([url, o]) => url.endsWith('/admin/lhws/l1/deactivate') && o.method === 'POST')).toBe(true);
  });

  it('resets a password only after the sync-before-reset warning (LI-8)', async () => {
    const fetchMock = mockApi({
      'GET /admin/lhws': [200, { lhws: [lhw()] }],
      'GET /admin/areas': [200, { areas }],
      'POST /admin/lhws/l1/reset-password': [200, { lhw: lhw(), credentials: { username: 'LHW-00001', password: 'Nw9pQr4StU' } }],
    });
    renderApp('/admin/lhws', { session: adminSession });

    fireEvent.click(await screen.findByRole('button', { name: 'Reset password of LHW-00001' }));
    const dialog = screen.getByRole('dialog', { name: 'Reset the password of LHW-00001?' });
    expect(within(dialog).getByText(/cannot be read after the reset \(LI-8\)/)).toBeInTheDocument();
    expect(fetchMock.mock.calls.some(([url]) => url.endsWith('/reset-password'))).toBe(false);

    fireEvent.click(within(dialog).getByRole('button', { name: 'Reset password' }));

    const done = await screen.findByRole('dialog', { name: 'New password' });
    expect(within(done).getByText('Nw9pQr4StU')).toBeInTheDocument();
  });

  it('filters by status', async () => {
    const fetchMock = mockApi({
      'GET /admin/lhws': [200, { lhws: [lhw()] }],
      'GET /admin/lhws?status=inactive': [200, { lhws: [] }],
      'GET /admin/areas': [200, { areas }],
    });
    renderApp('/admin/lhws', { session: adminSession });
    await screen.findByText('Ayesha Khan');

    fireEvent.change(screen.getByLabelText('Status'), { target: { value: 'inactive' } });

    expect(await screen.findByText('No LHWs match.')).toBeInTheDocument();
    expect(fetchMock.mock.calls.some(([url]) => url.endsWith('/admin/lhws?status=inactive'))).toBe(true);
  });
});
