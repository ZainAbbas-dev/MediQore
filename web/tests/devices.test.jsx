import { fireEvent, screen, within } from '@testing-library/react';
import { adminSession, mockApi, renderApp, supervisorSession } from './helpers';

jest.mock('../src/components/AreaMap', () => function AreaMapStub() {
  return <div data-testid="area-map" />;
});

const device = {
  id: '9b2f4c1e-3d5a-4e6b-8c7d-1a2b3c4d5e6f',
  model: 'Tecno Spark',
  firstSeenAt: '2026-10-04T08:00:00.000Z',
  lastSeenAt: '2026-10-04T08:00:00.000Z',
  codeExpiresAt: null,
  user: { id: 'u1', username: 'LHW-00007', fullName: 'Sana Iqbal', role: 'lhw', lhwCode: 'LHW-00007', areaName: 'Area 0101-1' },
};

describe('phone approvals (M1 FE-2)', () => {
  it('lists phones waiting for a code', async () => {
    mockApi({ 'GET /devices/pending': [200, { devices: [device] }] });
    renderApp('/devices', { session: supervisorSession });

    const row = (await screen.findByText('Sana Iqbal')).closest('tr');
    expect(within(row).getByText('LHW-00007')).toBeInTheDocument();
    expect(within(row).getByText('Tecno Spark')).toBeInTheDocument();
    // The same suffix the app shows on its code screen.
    expect(within(row).getByText('4d5e6f')).toBeInTheDocument();
    expect(within(row).getByText('None issued')).toBeInTheDocument();
  });

  it('issues a one-time code and shows it once', async () => {
    const fetchMock = mockApi({
      'GET /devices/pending': [200, { devices: [device] }],
      [`POST /devices/${device.id}/code`]: [201, {
        code: '482913', expiresAt: '2026-10-05T08:00:00.000Z', purpose: 'first_login', device,
      }],
    });
    renderApp('/devices', { session: supervisorSession });

    fireEvent.click(await screen.findByRole('button', { name: 'Issue code' }));

    const notice = await screen.findByRole('region', { name: 'One-time code' });
    expect(within(notice).getByText('482913')).toBeInTheDocument();
    expect(within(notice).getByText(/phone whose ID ends in 4d5e6f/)).toBeInTheDocument();
    expect(fetchMock.mock.calls.some(([url, o]) => url.endsWith(`/devices/${device.id}/code`) && o.method === 'POST')).toBe(true);

    fireEvent.click(within(notice).getByRole('button', { name: 'Done' }));
    expect(screen.queryByText('482913')).not.toBeInTheDocument();
  });

  it('says when nothing is waiting', async () => {
    mockApi({ 'GET /devices/pending': [200, { devices: [] }] });
    renderApp('/devices', { session: adminSession });

    expect(await screen.findByText('No phones are waiting for approval.')).toBeInTheDocument();
  });
});

describe('navigation by role', () => {
  it('shows LHW accounts to admins only', async () => {
    mockApi({ 'GET /households': [200, { households: [] }] });
    const { unmount } = renderApp('/', { session: adminSession });
    expect(await screen.findByRole('link', { name: 'LHW accounts' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Phone approvals' })).toBeInTheDocument();
    unmount();
    sessionStorage.clear();

    renderApp('/', { session: supervisorSession });
    expect(await screen.findByRole('link', { name: 'Phone approvals' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'LHW accounts' })).not.toBeInTheDocument();
  });

  it('keeps supervisors out of the admin page', async () => {
    mockApi({});
    renderApp('/admin/lhws', { session: supervisorSession });

    expect(await screen.findByRole('heading', { name: 'Not available' })).toBeInTheDocument();
  });
});
