import { fireEvent, screen, within } from '@testing-library/react';
import { adminSession, mockApi, renderApp, supervisorSession } from './helpers';
import { formatWhen } from '../src/format';

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
  visits: { count: 4, lastVisitAt: '2026-10-03T06:30:00.000Z' },
  serverSeq: 12,
  syncedAt: '2026-10-01T10:00:00.000Z',
};

describe('registered women (M2, M10 FE-1)', () => {
  it("lists the women with their pregnancy file in short", async () => {
    mockApi({ 'GET /women': [200, { women: [woman], total: 1 }] });
    renderApp('/women', { session: supervisorSession });

    const row = (await screen.findByText('LHW-00007-0003')).closest('tr');
    for (const text of ['26', 'Area 0101-1', '3', '2026-10-01', '2 / 1 / 0', 'Asthma', 'LHW-00007', 'Recorded', '4']) {
      expect(within(row).getByText(text)).toBeInTheDocument();
    }
    expect(within(row).getByText(formatWhen('2026-10-03T06:30:00.000Z', new Date(), { withTime: false }))).toBeInTheDocument();
    expect(within(row).getByText('Husband: Synthetic Husband')).toBeInTheDocument();
    expect(row).toHaveTextContent('Synthetic Woman');
    expect(row).toHaveTextContent('Dhok Syedan');
    expect(screen.getByText('Showing 1 of 1')).toBeInTheDocument();
  });

  it("opens a woman's visits with vitals, blood sugar details and danger signs (M3 FE-1)", async () => {
    const visit = {
      id: 'v2', pregnancyId: 'p1', visitedAt: '2026-10-03T06:30:00.000Z',
      systolicBpMmhg: 150, diastolicBpMmhg: 96, weightKg: 58.5, temperatureC: 37.9, pulseBpm: 104,
      bloodSugarMmolL: 7.8, bloodSugarEnteredUnit: 'mg_dl', bloodSugarMeasuredOn: '2026-10-02', bloodSugarSource: 'glucometer',
      fetalMovement: 'reduced', swelling: true, bleeding: false, fever: true, anaemiaSigns: 'severe', urineSymptoms: false,
      convulsions: false, severeHeadache: true, blurredVision: true, severeAbdominalPain: false, fastBreathing: false, feverWithWeakness: false,
      recordedBy: { lhwCode: 'LHW-00007', fullName: 'Sana Iqbal' }, serverSeq: 40, syncedAt: '2026-10-03T07:00:00.000Z',
    };
    const earlier = {
      ...visit, id: 'v1', serverSeq: 31, bloodSugarMmolL: null, bloodSugarEnteredUnit: null, bloodSugarMeasuredOn: null,
      bloodSugarSource: null, severeHeadache: null, blurredVision: null, convulsions: null, severeAbdominalPain: null,
      fastBreathing: null, feverWithWeakness: null,
    };
    mockApi({
      'GET /women': [200, { women: [woman], total: 1 }],
      [`GET /women/${woman.id}/visits`]: [200, { visits: [visit, earlier] }],
    });
    renderApp('/women', { session: supervisorSession });

    fireEvent.click(await screen.findByRole('button', { name: 'Visits of Synthetic Woman' }));

    const dialog = screen.getByRole('dialog', { name: 'Visits of Synthetic Woman (LHW-00007-0003)' });
    const [latest, first] = await within(dialog).findAllByRole('article');
    expect(latest).toHaveTextContent('150/96 mmHg');
    expect(latest).toHaveTextContent('104 /min');
    expect(latest).toHaveTextContent('7.8 mmol/L (glucometer, 2026-10-02, typed in mg/dL)');
    expect(latest).toHaveTextContent('Markedly reduced');
    expect(within(latest).getByText('Danger signs: Severe headache, Blurred vision')).toBeInTheDocument();
    expect(first).toHaveTextContent('Not tested');
    expect(first).toHaveTextContent('No danger sign answered yes (6 not asked).');
    expect(within(dialog).getByText(/decision support only \(LI-5\)/)).toBeInTheDocument();

    fireEvent.click(within(dialog).getByRole('button', { name: 'Close' }));
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
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
    const noGps = {
      ...woman,
      household: { ...woman.household, latitude: null, longitude: null },
      obstetricHistory: null,
      visits: { count: 0, lastVisitAt: null },
    };
    mockApi({ 'GET /women': [200, { women: [noGps], total: 1 }] });
    renderApp('/women', { session: supervisorSession });

    const row = (await screen.findByText('LHW-00007-0003')).closest('tr');
    expect(within(row).getByText('Not recorded')).toBeInTheDocument();
  });

  it('is in the sidebar for supervisors and admins', async () => {
    mockApi({ 'GET /households': [200, { households: [] }], 'GET /dashboard/summary': [200, { registeredWomen: 0, visitsThisWeek: 0, pendingConflicts: 0 }] });
    renderApp('/', { session: supervisorSession });

    expect(await screen.findByRole('link', { name: 'Registered women' })).toBeInTheDocument();
  });
});
