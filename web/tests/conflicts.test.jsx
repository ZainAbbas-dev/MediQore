import { fireEvent, screen, within } from '@testing-library/react';
import { adminSession, mockApi, renderApp, supervisorSession } from './helpers';

jest.mock('../src/components/AreaMap', () => function AreaMapStub() {
  return <div data-testid="area-map" />;
});

const visit = {
  pregnancyId: '3a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d',
  visitedAt: '2026-10-03T06:30:00.000Z',
  systolicBpMmhg: 120,
  diastolicBpMmhg: 80,
  weightKg: 61.5,
  temperatureC: 36.9,
  pulseBpm: 84,
  bloodSugarMmolL: null,
  fetalMovement: 'normal',
  swelling: false,
  bleeding: false,
  fever: false,
  anaemiaSigns: 'none',
  urineSymptoms: false,
};

const pending = {
  id: '7c6b5a49-3827-4e16-9d0c-bafedcba9876',
  table: 'visits',
  reason: 'same_parent_same_day',
  status: 'pending',
  resolution: null,
  createdAt: '2026-10-03T07:00:00.000Z',
  resolvedAt: null,
  resolvedBy: null,
  areaId: 'a1',
  areaName: 'Area 0101-1',
  submittedBy: { lhwCode: 'LHW-00007', fullName: 'Sana Iqbal' },
  woman: { name: 'Synthetic Woman', patientCode: 'LHW-00007-0003' },
  existing: { id: 'e1', deleted: false, data: visit },
  incoming: { id: 'i1', data: { ...visit, visitedAt: '2026-10-03T09:10:00.000Z', systolicBpMmhg: 165, bleeding: true } },
};

const resolved = {
  ...pending,
  status: 'resolved',
  resolution: 'keep_both',
  resolvedAt: '2026-10-03T08:00:00.000Z',
  resolvedBy: 'Demo Supervisor',
};

describe('sync conflict queue (M3 FE-2, M10)', () => {
  it('shows the held visit next to the stored one, with the differences marked', async () => {
    mockApi({ 'GET /conflicts?status=pending': [200, { conflicts: [pending] }] });
    renderApp('/conflicts', { session: supervisorSession });

    const card = await screen.findByRole('region', { name: 'Conflict LHW-00007-0003' });
    expect(within(card).getByRole('heading', { name: 'Synthetic Woman (LHW-00007-0003)' })).toBeInTheDocument();
    expect(card).toHaveTextContent('Same-day visit sent by LHW-00007 in Area 0101-1');

    const systolic = within(card).getByRole('rowheader', { name: 'Systolic BP' }).closest('tr');
    expect(within(systolic).getByText('120 mmHg')).toBeInTheDocument();
    expect(within(systolic).getByText('165 mmHg')).toBeInTheDocument();
    expect(systolic).toHaveClass('differs');
    const bleeding = within(card).getByRole('rowheader', { name: 'Bleeding' }).closest('tr');
    expect(within(bleeding).getAllByText(/Yes|No/).map((cell) => cell.textContent)).toEqual(['No', 'Yes']);
    expect(bleeding).toHaveClass('differs');
    expect(within(card).getByRole('rowheader', { name: 'Weight' }).closest('tr')).not.toHaveClass('differs');
    expect(within(card).getByRole('rowheader', { name: 'Blood sugar' }).closest('tr')).toHaveTextContent('–');
  });

  it('records the decision and reloads the queue', async () => {
    let decided = false;
    const fetchMock = mockApi({
      'GET /conflicts?status=pending': () => [200, { conflicts: decided ? [] : [pending] }],
      [`POST /conflicts/${pending.id}/resolve`]: () => {
        decided = true;
        return [200, { conflict: resolved }];
      },
    });
    renderApp('/conflicts', { session: supervisorSession });

    fireEvent.click(await screen.findByRole('button', { name: 'Keep both visits' }));

    const notice = await screen.findByRole('region', { name: 'Decision saved' });
    expect(notice).toHaveTextContent('Both visits kept for Synthetic Woman (LHW-00007-0003).');
    expect(await screen.findByText('No visits are waiting for a decision.')).toBeInTheDocument();
    const post = fetchMock.mock.calls.find(([, options]) => options.method === 'POST');
    expect(post[0]).toMatch(new RegExp(`/conflicts/${pending.id}/resolve$`));
    expect(JSON.parse(post[1].body)).toEqual({ resolution: 'keep_both' });
  });

  it.each([
    ['Keep the stored visit', 'keep_existing'],
    ['Keep the held visit', 'keep_incoming'],
  ])('"%s" sends %s', async (button, resolution) => {
    const fetchMock = mockApi({
      'GET /conflicts?status=pending': [200, { conflicts: [pending] }],
      [`POST /conflicts/${pending.id}/resolve`]: [200, { conflict: { ...resolved, resolution } }],
    });
    renderApp('/conflicts', { session: adminSession });

    fireEvent.click(await screen.findByRole('button', { name: button }));

    await screen.findByRole('region', { name: 'Decision saved' });
    const post = fetchMock.mock.calls.find(([, options]) => options.method === 'POST');
    expect(JSON.parse(post[1].body)).toEqual({ resolution });
  });

  it('shows decided conflicts with who decided, without buttons', async () => {
    mockApi({
      'GET /conflicts?status=pending': [200, { conflicts: [] }],
      'GET /conflicts?status=resolved': [200, { conflicts: [resolved] }],
    });
    renderApp('/conflicts', { session: supervisorSession });
    expect(await screen.findByText('No visits are waiting for a decision.')).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText('Show'), { target: { value: 'resolved' } });

    const card = await screen.findByRole('region', { name: 'Conflict LHW-00007-0003' });
    expect(card).toHaveTextContent('Both visits kept, by Demo Supervisor');
    expect(within(card).queryByRole('button')).not.toBeInTheDocument();
  });

  it('shows an error from the API, for example a conflict decided meanwhile', async () => {
    mockApi({
      'GET /conflicts?status=pending': [200, { conflicts: [pending] }],
      [`POST /conflicts/${pending.id}/resolve`]: [409, { error: { code: 'ALREADY_RESOLVED', message: 'This conflict has already been resolved' } }],
    });
    renderApp('/conflicts', { session: supervisorSession });

    fireEvent.click(await screen.findByRole('button', { name: 'Keep both visits' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('This conflict has already been resolved');
  });

  it('is in the sidebar for supervisors and admins', async () => {
    mockApi({
      'GET /households': [200, { households: [] }],
      'GET /dashboard/summary': [200, { registeredWomen: 0, visitsThisWeek: 0, pendingConflicts: 0 }],
    });
    renderApp('/', { session: adminSession });

    expect(await screen.findByRole('link', { name: 'Sync conflicts' })).toHaveAttribute('href', '/conflicts');
  });
});
