import { fireEvent, screen, within } from '@testing-library/react';
import { adminSession, mockApi, renderApp, supervisorSession } from './helpers';

jest.mock('../src/components/AreaMap', () => function AreaMapStub() {
  return <div data-testid="area-map" />;
});

const woman = {
  id: '5d2c7a1e-8b3f-4c6d-9e0a-1b2c3d4e5f60',
  patientCode: 'LHW-00007-0003',
  name: 'Synthetic Woman',
  age: 26,
  husbandName: 'Synthetic Husband',
  contactNumber: '0000-1234567',
  areaId: 'a1',
  areaName: 'Area 0101-1',
  household: { id: 'h1', village: 'Dhok Syedan', address: 'House 12', latitude: 33.6844, longitude: 73.0479 },
  registeredBy: { lhwCode: 'LHW-00007', fullName: 'Sana Iqbal' },
  pregnancy: { registeredOn: '2026-10-01', monthAtRegistration: 3, status: 'active' },
  obstetricHistory: { previousPregnancies: 2, previousCSections: 1, stillbirths: 0, knownConditions: 'Asthma' },
  serverSeq: 12,
  syncedAt: '2026-10-01T10:00:00.000Z',
};

describe('registered women (M2, M10 FE-1)', () => {
  it("lists the women with their pregnancy file in short", async () => {
    mockApi({ 'GET /women': [200, { women: [woman], total: 1 }] });
    renderApp('/women', { session: supervisorSession });

    const row = (await screen.findByText('LHW-00007-0003')).closest('tr');
    for (const text of ['26', 'Area 0101-1', '3', '2026-10-01', '2 / 1 / 0', 'Asthma', 'LHW-00007', 'Recorded']) {
      expect(within(row).getByText(text)).toBeInTheDocument();
    }
    expect(within(row).getByText('Husband: Synthetic Husband')).toBeInTheDocument();
    expect(row).toHaveTextContent('Synthetic Woman');
    expect(row).toHaveTextContent('Dhok Syedan');
    expect(screen.getByText('Showing 1 of 1')).toBeInTheDocument();
  });

  it('searches through the API', async () => {
    const fetchMock = mockApi({
      'GET /women': [200, { women: [woman], total: 1 }],
      'GET /women?search=dhok': [200, { women: [], total: 0 }],
    });
    renderApp('/women', { session: adminSession });
    await screen.findByText('LHW-00007-0003');

    fireEvent.change(screen.getByLabelText('Search'), { target: { value: 'dhok' } });

    expect(await screen.findByText('No registered woman matches.')).toBeInTheDocument();
    expect(fetchMock.mock.calls.some(([url]) => url.endsWith('/women?search=dhok'))).toBe(true);
  });

  it('says when nobody is registered yet', async () => {
    mockApi({ 'GET /women': [200, { women: [], total: 0 }] });
    renderApp('/women', { session: supervisorSession });

    expect(await screen.findByText('No women have been registered yet.')).toBeInTheDocument();
  });

  it('shows a home without GPS as not recorded', async () => {
    const noGps = { ...woman, household: { ...woman.household, latitude: null, longitude: null }, obstetricHistory: null };
    mockApi({ 'GET /women': [200, { women: [noGps], total: 1 }] });
    renderApp('/women', { session: supervisorSession });

    const row = (await screen.findByText('LHW-00007-0003')).closest('tr');
    expect(within(row).getByText('Not recorded')).toBeInTheDocument();
  });

  it('is in the sidebar for supervisors and admins', async () => {
    mockApi({ 'GET /households': [200, { households: [] }], 'GET /women?limit=1': [200, { women: [], total: 0 }] });
    renderApp('/', { session: supervisorSession });

    expect(await screen.findByRole('link', { name: 'Registered women' })).toBeInTheDocument();
  });
});
