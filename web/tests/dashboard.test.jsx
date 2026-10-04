import { screen } from '@testing-library/react';
import { mockApi, renderApp, supervisorSession } from './helpers';

jest.mock('../src/components/AreaMap', () => function AreaMapStub({ households = [] }) {
  return <div data-testid="area-map">{households.length} on map</div>;
});

const household = {
  id: '0b7f8e2a-3c4d-4e5f-8a9b-1c2d3e4f5a6b',
  householdNumber: 'TEST-1',
  village: 'Test village',
  address: null,
  latitude: 33.6844,
  longitude: 73.0479,
  areaId: 'a1',
  areaName: 'Demo Area 1',
  serverSeq: 7,
  syncedAt: '2026-10-03T10:00:00.000Z',
  createdOnDevice: '2026-10-03T09:58:00.000Z',
};

describe('dashboard', () => {
  it('shows the households synced from the LHW app and the summary counts (M10 FE-1)', async () => {
    const fetchMock = mockApi({
      'GET /households': [200, { households: [household] }],
      'GET /dashboard/summary': [200, { registeredWomen: 37, visitsThisWeek: 12, pendingConflicts: 2 }],
    });

    renderApp('/', { session: supervisorSession });

    expect(await screen.findByText('Test village')).toBeInTheDocument();
    expect(screen.getByText('TEST-1')).toBeInTheDocument();
    expect(screen.getByText('Demo Area 1')).toBeInTheDocument();
    expect(screen.getByTestId('area-map')).toHaveTextContent('1 on map');
    expect(screen.getByText('Registered households').previousSibling).toHaveTextContent('1');
    expect(screen.getByText('Registered women', { selector: '.card-label' }).closest('.card')).toHaveTextContent('37');
    expect(screen.getByText('Visits this week').closest('.card')).toHaveTextContent('12');
    const conflicts = screen.getByRole('link', { name: 'Sync conflicts to review' });
    expect(conflicts.closest('.card')).toHaveTextContent('2');
    expect(conflicts).toHaveAttribute('href', '/conflicts');
    expect(fetchMock.mock.calls[0][1].headers.Authorization).toBe('Bearer token-1');
  });

  it('says so when nothing has been synced yet', async () => {
    mockApi({ 'GET /households': [200, { households: [] }], 'GET /dashboard/summary': [200, { registeredWomen: 0, visitsThisWeek: 0, pendingConflicts: 0 }] });

    renderApp('/', { session: supervisorSession });

    expect(await screen.findByText('No households have been synced yet.')).toBeInTheDocument();
  });

  it('signs out when the session has expired', async () => {
    mockApi({ 'GET /households': [401, { error: { code: 'UNAUTHORIZED', message: 'Session expired or invalid' } }] });

    renderApp('/', { session: supervisorSession });

    expect(await screen.findByLabelText('Username')).toBeInTheDocument();
  });

  it('shows other API errors', async () => {
    mockApi({ 'GET /households': [500, { error: { code: 'INTERNAL_ERROR', message: 'Something went wrong' } }] });

    renderApp('/', { session: supervisorSession });

    expect(await screen.findByRole('alert')).toHaveTextContent('Something went wrong');
  });

  it('has a not-found page inside the layout', async () => {
    mockApi({});

    renderApp('/nowhere', { session: supervisorSession });

    expect(await screen.findByRole('heading', { name: 'Page not found' })).toBeInTheDocument();
    expect(screen.getByRole('navigation', { name: 'Main' })).toBeInTheDocument();
  });
});
