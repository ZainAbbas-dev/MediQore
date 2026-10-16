import { act, fireEvent, screen, within } from '@testing-library/react';
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
  unionCouncilName: 'UC 1',
  registeredBy: 'LHW-00007',
  serverSeq: 7,
  syncedAt: '2026-10-03T10:00:00.000Z',
  createdOnDevice: '2026-10-03T09:58:00.000Z',
};

const filters = {
  districts: [{ id: 'd1', name: 'Rawalpindi' }, { id: 'd2', name: 'Attock' }],
  unionCouncils: [
    { id: 'uc1', name: 'UC 1', districtId: 'd1' },
    { id: 'uc2', name: 'UC 2', districtId: 'd2' },
  ],
  lhws: [
    { id: 'l1', lhwCode: 'LHW-00007', fullName: 'Sana Iqbal', unionCouncilId: 'uc1', districtId: 'd1' },
    { id: 'l2', lhwCode: 'LHW-00009', fullName: 'Hina Bibi', unionCouncilId: 'uc2', districtId: 'd2' },
  ],
};

const activity = {
  lhws: [{
    id: 'l1', lhwCode: 'LHW-00007', fullName: 'Sana Iqbal', isActive: true, area: 'Demo Area 1', unionCouncil: 'UC 1',
    district: 'Rawalpindi', visitsThisWeek: 3, visitsTotal: 41, womenRegistered: 12, lastVisitAt: '2026-10-04T05:00:00.000Z',
    lastSyncAt: '2026-10-04T06:00:00.000Z', lastLoginAt: null,
  }],
};

const summary = { registeredWomen: 37, visitsThisWeek: 12, pendingConflicts: 2, lhws: 16, lhwsSyncedToday: 13 };

// The dashboard's answers; `overrides` replaces some of them.
function dashboardApi(overrides = {}) {
  return mockApi({
    'GET /dashboard/filters': [200, filters],
    'GET /dashboard/summary': [200, summary],
    'GET /dashboard/lhw-activity': [200, activity],
    'GET /households': [200, { households: [household] }],
    ...overrides,
  });
}

const requested = (fetchMock, path) => fetchMock.mock.calls.filter(([url]) => url.endsWith(path)).length;

describe('dashboard (M10 FE-1)', () => {
  afterEach(() => jest.useRealTimers());

  it('shows the cards, the households on the map and each LHW\'s activity (screen 20)', async () => {
    jest.useFakeTimers({ now: new Date('2026-10-04T12:00:00.000Z'), doNotFake: ['setTimeout', 'queueMicrotask', 'nextTick', 'setImmediate'] });
    const fetchMock = dashboardApi();

    renderApp('/', { session: supervisorSession });

    expect(await screen.findByText('1 on map')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: /Households with GPS/ })).toHaveTextContent('Households with GPS · 1');
    const card = (label) => screen.getByText(label, { selector: '.card-label' }).closest('.card');
    await screen.findByText('37');
    expect(card('Registered women')).toHaveTextContent('37');
    expect(card('Visits this week')).toHaveTextContent('12');
    expect(card('LHWs synced today')).toHaveTextContent('13of 16');
    const conflicts = screen.getByRole('link', { name: 'Sync conflicts to review' });
    expect(conflicts.closest('.card')).toHaveTextContent('2');
    expect(conflicts.closest('.card')).toHaveClass('attention');
    expect(conflicts).toHaveAttribute('href', '/conflicts');

    const row = (await screen.findByText('Sana Iqbal')).closest('tr');
    for (const text of ['LHW-00007', '3', '41', '12', 'Never']) expect(within(row).getByText(text)).toBeInTheDocument();
    expect(row).toHaveTextContent('UC 1, Rawalpindi');
    expect(row).toHaveTextContent(/Today \d/);
    expect(row).not.toHaveClass('stale');
    expect(fetchMock.mock.calls[0][1].headers.Authorization).toBe('Bearer token-1');
  });

  it('highlights an LHW who has not synced for two days or more', async () => {
    jest.useFakeTimers({ now: new Date('2026-10-08T12:00:00.000Z'), doNotFake: ['setTimeout', 'queueMicrotask', 'nextTick', 'setImmediate'] });
    const never = { ...activity.lhws[0], id: 'l2', lhwCode: 'LHW-00009', fullName: 'Hina Bibi', lastSyncAt: null };
    dashboardApi({ 'GET /dashboard/lhw-activity': [200, { lhws: [activity.lhws[0], never] }] });

    renderApp('/', { session: supervisorSession });

    const row = (await screen.findByText('Sana Iqbal')).closest('tr');
    expect(row).toHaveClass('stale');
    expect(row.querySelector('.stale-text')).toHaveTextContent('4 days ago');
    expect(screen.getByText('Hina Bibi').closest('tr')).toHaveClass('stale');
    expect(screen.getByText('Highlighted: no sync for 2 days or more.')).toBeInTheDocument();
  });

  it('filters the cards, the map and LHW activity by district, Union Council, LHW and period', async () => {
    const fetchMock = dashboardApi({
      'GET /households?districtId=d1': [200, { households: [] }],
      'GET /dashboard/summary?districtId=d1': [200, { ...summary, registeredWomen: 5 }],
      'GET /dashboard/lhw-activity?districtId=d1': [200, activity],
      'GET /households?districtId=d1&lhwId=l1': [200, { households: [household] }],
      'GET /dashboard/summary?districtId=d1&lhwId=l1': [200, summary],
      'GET /dashboard/lhw-activity?districtId=d1&lhwId=l1': [200, activity],
      'GET /households?districtId=d1&lhwId=l1&days=30': [200, { households: [] }],
    });
    renderApp('/', { session: supervisorSession });
    await screen.findByText('1 on map');
    await screen.findByRole('option', { name: 'Rawalpindi' });

    fireEvent.change(screen.getByLabelText('District'), { target: { value: 'd1' } });
    expect(await screen.findByText('No households match these filters.')).toBeInTheDocument();
    expect(await screen.findByText('5')).toBeInTheDocument();
    expect(requested(fetchMock, '/dashboard/lhw-activity?districtId=d1')).toBe(1);
    // Only the chosen district's Union Councils and LHWs are offered.
    expect(within(screen.getByLabelText('Union Council')).queryByRole('option', { name: 'UC 2' })).not.toBeInTheDocument();
    expect(within(screen.getByLabelText('LHW')).getAllByRole('option').map((o) => o.textContent)).toEqual(['All', 'LHW-00007 · Sana Iqbal']);

    fireEvent.change(screen.getByLabelText('LHW'), { target: { value: 'l1' } });
    expect(await screen.findByText('1 on map')).toBeInTheDocument();
    expect(requested(fetchMock, '/dashboard/summary?districtId=d1&lhwId=l1')).toBe(1);
    expect(requested(fetchMock, '/dashboard/lhw-activity?districtId=d1&lhwId=l1')).toBe(1);
    fireEvent.change(screen.getByLabelText('Period'), { target: { value: '30' } });
    expect(await screen.findByText('No households match these filters.')).toBeInTheDocument();
    expect(requested(fetchMock, '/households?districtId=d1&lhwId=l1&days=30')).toBe(1);
    // The period is for the map only.
    expect(requested(fetchMock, '/dashboard/summary?districtId=d1&lhwId=l1')).toBe(2);

    fireEvent.click(screen.getByRole('button', { name: 'Clear filters' }));
    expect(await screen.findByText('1 on map')).toBeInTheDocument();
    expect(screen.getByLabelText('District')).toHaveValue('');
  });

  it('refreshes itself every five minutes and on Reload', async () => {
    jest.useFakeTimers();
    const fetchMock = dashboardApi();
    renderApp('/', { session: supervisorSession });
    await screen.findByText('1 on map');
    expect(requested(fetchMock, '/households')).toBe(1);

    await act(async () => {
      jest.advanceTimersByTime(5 * 60 * 1000);
    });
    expect(requested(fetchMock, '/households')).toBe(2);
    expect(requested(fetchMock, '/dashboard/summary')).toBe(2);

    fireEvent.click(screen.getByRole('button', { name: 'Reload' }));
    await act(async () => {});
    expect(requested(fetchMock, '/households')).toBe(3);
    expect(screen.getByText(/Refreshes every 5 minutes/)).toBeInTheDocument();
  });

  it('says so when nothing has been synced yet', async () => {
    dashboardApi({ 'GET /households': [200, { households: [] }], 'GET /dashboard/lhw-activity': [200, { lhws: [] }] });

    renderApp('/', { session: supervisorSession });

    expect(await screen.findByText('No households have been synced yet.')).toBeInTheDocument();
    expect(await screen.findByText('No LHWs in these areas.')).toBeInTheDocument();
  });

  it('signs out when the session has expired', async () => {
    mockApi({ 'GET /households': [401, { error: { code: 'UNAUTHORIZED', message: 'Session expired or invalid' } }] });

    renderApp('/', { session: supervisorSession });

    expect(await screen.findByLabelText('Username')).toBeInTheDocument();
  });

  it('shows an API error and still shows the parts that loaded', async () => {
    dashboardApi({ 'GET /households': [500, { error: { code: 'INTERNAL_ERROR', message: 'Something went wrong' } }] });

    renderApp('/', { session: supervisorSession });

    expect(await screen.findByRole('alert')).toHaveTextContent('Something went wrong');
    expect(await screen.findByText('Sana Iqbal')).toBeInTheDocument();
  });

  it('has a not-found page inside the layout', async () => {
    mockApi({});

    renderApp('/nowhere', { session: supervisorSession });

    expect(await screen.findByRole('heading', { name: 'Page not found' })).toBeInTheDocument();
    expect(screen.getByRole('navigation', { name: 'Main' })).toBeInTheDocument();
  });
});
