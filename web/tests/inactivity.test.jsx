import { fireEvent, screen, within } from '@testing-library/react';
import { mockApi, renderApp, supervisorSession } from './helpers';

const workerId = 'bf0afa4b-a3aa-423c-a382-1e0d10911a14';
const weekStart = '2026-11-16';
const worker = {
  id: workerId,
  fullName: 'Nadia Parveen',
  lhwCode: 'LHW-41',
  area: 'Rural Health Centre',
  lastSyncAt: '2026-11-22T19:00:00.000Z',
  inactivity: { status: 'unusual_inactivity', visits: 1, historyWeeks: 6, exclusion: null },
};
const endpoint = `/inactivity/${workerId}/exclusions`;

it('shows the latest closed Pakistan week and the supervisor verification prompt', async () => {
  mockApi({
    'GET /inactivity': [200, { weekStart, lhws: [
      worker,
      { ...worker, id: 'other-worker', fullName: 'Amina Shah', lhwCode: 'LHW-53', lastSyncAt: '2026-11-15T20:00:00.000Z',
        inactivity: { status: 'not_synced', visits: null, historyWeeks: null, exclusion: null } },
    ] }],
  });

  renderApp('/activity', { session: supervisorSession });

  expect(await screen.findByText('Unusual inactivity')).toBeInTheDocument();
  expect(screen.getByText('Verify field activity with this LHW.')).toBeInTheDocument();
  expect(screen.getByText('Not synced since 16 Nov 2026')).toBeInTheDocument();
  expect(screen.getByText(/16 Nov 2026.*22 Nov 2026/)).toBeInTheDocument();
});

it('lets a supervisor mark and remove an exclusion and updates the weekly status', async () => {
  let exclusion = null;
  mockApi({
    'GET /inactivity': () => [200, { weekStart, lhws: [
      exclusion
        ? { ...worker, inactivity: { ...worker.inactivity, status: 'excluded', exclusion: exclusion.kind } }
        : worker,
    ] }],
    [`GET ${endpoint}`]: () => [200, { exclusions: exclusion ? [exclusion] : [] }],
    [`PUT ${endpoint}/${weekStart}`]: ({ body }) => {
      const { kind } = JSON.parse(body);
      exclusion = { id: 'saved-exclusion', weekStart, kind, markedBy: supervisorSession.user.id, createdAt: '2026-11-25T00:00:00.000Z' };
      return [200, { exclusion }];
    },
    [`DELETE ${endpoint}/${weekStart}`]: () => {
      exclusion = null;
      return [204];
    },
  });

  renderApp('/activity', { session: supervisorSession });

  fireEvent.click(await screen.findByRole('button', { name: 'Manage excluded weeks for Nadia Parveen' }));
  const dialog = screen.getByRole('dialog');
  fireEvent.change(await within(dialog).findByRole('combobox', { name: 'Reason' }), { target: { value: 'campaign' } });
  fireEvent.click(within(dialog).getByRole('button', { name: 'Save excluded week' }));
  expect(await within(dialog).findByText('Campaign week')).toBeInTheDocument();
  expect(await screen.findByText('Excluded for campaign')).toBeInTheDocument();

  fireEvent.click(within(dialog).getByRole('button', { name: 'Remove exclusion for 16 Nov 2026' }));
  expect(await within(dialog).findByText('No excluded weeks.')).toBeInTheDocument();
  expect(await screen.findByText('Unusual inactivity')).toBeInTheDocument();
});

it('allows viewing excluded weeks when the role has records access alone', async () => {
  mockApi({
    'GET /inactivity': [200, { weekStart, lhws: [worker] }],
    [`GET ${endpoint}`]: [200, { exclusions: [] }],
  });
  const session = {
    ...supervisorSession,
    user: { ...supervisorSession.user, permissions: ['records.view'] },
  };

  renderApp('/activity', { session });

  fireEvent.click(await screen.findByRole('button', { name: 'View excluded weeks for Nadia Parveen' }));
  const dialog = screen.getByRole('dialog');
  expect(await within(dialog).findByText('No excluded weeks.')).toBeInTheDocument();
  expect(within(dialog).queryByRole('button', { name: 'Save excluded week' })).not.toBeInTheDocument();
});
