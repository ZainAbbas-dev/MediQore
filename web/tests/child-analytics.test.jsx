import { fireEvent, screen, within } from '@testing-library/react';
import { mockApi, renderApp, supervisorSession } from './helpers';

jest.mock('../src/components/AreaMap', () => function AreaMapStub() {
  return <div data-testid="area-map" />;
});

const filters = {
  districts: [{ id: 'd1', name: 'Test district' }],
  areas: [{ id: 'a1', name: 'Test area', districtId: 'd1' }],
  rounds: [{ id: 'r1', name: 'Spring round', startsOn: '2026-05-01', endsOn: '2026-06-01' }],
};
const child = {
  id: 'c1', name: 'Fixture Child', dateOfBirth: '2026-01-01', sex: 'female', status: 'active',
  areaName: 'Test area', village: 'Test village', zeroDose: true, noOpv: false,
  latestScreening: { screenedOn: '2026-05-03', malnutritionClass: 'mam', stunting: true },
};
const antigen = { antigen: 'Penta', percentage: 50, eligible: 2, fullyVaccinated: 1, lowCoverage: true };
const coverage = {
  asOf: '2026-06-01', scheduleVersion: 'pk-epi-2022.1', reviewStatus: 'pending_clinical_review',
  coverageThreshold: 90, totalChildren: 2, zeroDose: 1, noOpv: 0, antigens: [antigen],
  areas: [{ areaId: 'a1', areaName: 'Test area', antigens: [antigen] }],
};
const progress = {
  householdsVisited: 3, childrenEligible: 4, childrenVaccinated: 2, partialHouseholds: 1,
  refusalHouseholds: 0, notAvailableHouseholds: 1, noEligibleHouseholds: 1, allVaccinatedHouseholds: 0,
  refusals: 1, noOpv: 1,
};
const polio = {
  asOf: '2026-06-01', summary: progress, areas: [{ areaId: 'a1', areaName: 'Test area', ...progress }],
  rounds: [], total: 1, page: 1, limit: 25,
  households: [{ id: 'v1', areaName: 'Test area', village: 'Test village', roundName: 'Spring round',
    householdNumber: 'H-12', visitedOn: '2026-05-10', status: 'partially_covered', childrenEligible: 2,
    childrenVaccinated: 1, refusals: 1, refusalReasons: ['past_reaction'], nextRevisitOn: '2026-05-20' }],
};

test('shows per-antigen coverage and pages the registered children after follow-up changes', async () => {
  mockApi({
    'GET /child-analytics/filters': [200, filters],
    'GET /child-analytics/children': [200, { children: [child], total: 26, page: 1, limit: 25 }],
    'GET /child-analytics/children?page=2': [200, { children: [{ ...child, name: 'Second page' }], total: 26, page: 2, limit: 25 }],
    'GET /child-analytics/children?followUp=no-opv': [200, { children: [], total: 0, page: 1, limit: 25 }],
    'GET /child-analytics/coverage': [200, coverage],
  });
  renderApp('/children', { session: supervisorSession });
  expect(await screen.findByText('Fixture Child')).toBeInTheDocument();
  const overall = screen.getByRole('region', { name: 'Routine immunisation coverage' });
  expect(within(overall).getByText('50%')).toBeInTheDocument();
  expect(within(overall).getByText('Below 90%')).toBeInTheDocument();
  fireEvent.click(screen.getByRole('button', { name: 'Next page' }));
  expect(await screen.findByText('Second page')).toBeInTheDocument();
  fireEvent.change(screen.getByLabelText('Follow-up'), { target: { value: 'no-opv' } });
  expect(await screen.findByText('No children match these filters.')).toBeInTheDocument();
});

test('shows campaign statuses and changes rounds without leaking the previous result', async () => {
  mockApi({
    'GET /child-analytics/filters': [200, filters],
    'GET /child-analytics/polio': [200, polio],
    'GET /child-analytics/polio?roundId=r1': [200, { ...polio, households: [], total: 0 }],
  });
  renderApp('/polio', { session: supervisorSession });
  const row = (await screen.findByText('H-12')).closest('tr');
  expect(row).toHaveTextContent('Partially covered');
  expect(row).toHaveTextContent('Past reaction');
  expect(row).toHaveTextContent('2026-05-20');
  fireEvent.change(screen.getByLabelText('Campaign round'), { target: { value: 'r1' } });
  expect(await screen.findByText('No campaign household records match these filters.')).toBeInTheDocument();
  expect(screen.queryByText('H-12')).not.toBeInTheDocument();
});
