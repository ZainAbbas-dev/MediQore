import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import { adminSession, mockApi, renderApp } from './helpers';

const areas = [
  { id: 'area-a', district: 'District A', tehsil: 'Tehsil A', unionCouncil: 'UC A', name: 'Area A' },
  { id: 'area-b', district: 'District B', tehsil: 'Tehsil B', unionCouncil: 'UC B', name: 'Area B' },
];
const contacts = '/area-config/escalation-contacts';
const campaigns = '/area-config/campaign-rounds';

it('saves an area contact with its supervisor and secondary numbers', async () => {
  let contact;
  mockApi({
    [`GET ${contacts}/options`]: [200, {
      areas,
      supervisors: [
        { userId: 'supervisor-a', areaId: 'area-a', fullName: 'Synthetic Supervisor', phone: '0000-0000001' },
        { userId: 'supervisor-b', areaId: 'area-a', fullName: 'Synthetic Alternate Supervisor', phone: null },
      ],
    }],
    [`GET ${contacts}`]: () => [200, { contacts: contact ? [contact] : [] }],
    [`PUT ${contacts}/area-a`]: ({ body }) => {
      contact = { id: 'contact-a', area: areas[0], ...JSON.parse(body) };
      return [201, { contact }];
    },
  });
  renderApp('/admin/escalation-contacts', { session: adminSession });

  const add = screen.getByRole('button', { name: 'Add escalation contact' });
  await waitFor(() => expect(add).toBeEnabled());
  fireEvent.click(add);
  const dialog = within(screen.getByRole('dialog'));
  fireEvent.change(dialog.getByLabelText('Area'), { target: { value: 'area-a' } });
  fireEvent.change(dialog.getByLabelText('Assigned supervisor (optional)'), { target: { value: 'supervisor-a' } });
  expect(dialog.getByLabelText('Supervisor phone')).toHaveValue('0000-0000001');
  fireEvent.change(dialog.getByLabelText('Assigned supervisor (optional)'), { target: { value: 'supervisor-b' } });
  expect(dialog.getByLabelText('Supervisor phone')).toHaveValue('');
  fireEvent.change(dialog.getByLabelText('Assigned supervisor (optional)'), { target: { value: 'supervisor-a' } });
  fireEvent.change(dialog.getByLabelText('Secondary contact name (optional)'), { target: { value: 'Synthetic District Hospital' } });
  fireEvent.change(dialog.getByLabelText('Secondary contact phone (optional)'), { target: { value: '0000-0000002' } });
  fireEvent.click(dialog.getByRole('button', { name: 'Save contact' }));

  expect(await screen.findByText('Synthetic District Hospital')).toBeInTheDocument();
  expect(screen.getByText('0000-0000002')).toBeInTheDocument();
  expect(contact).toMatchObject({ supervisorUserId: 'supervisor-a', escalateAfterMinutes: 15 });
});

it('creates a campaign with more than one target area', async () => {
  let round;
  mockApi({
    [`GET ${campaigns}/options`]: [200, { areas }],
    [`GET ${campaigns}`]: () => [200, { rounds: round ? [round] : [] }],
    [`POST ${campaigns}`]: ({ body }) => {
      const { areaIds, ...values } = JSON.parse(body);
      round = { id: 'round-a', ...values, areas: areas.filter((a) => areaIds.includes(a.id)), editable: true };
      return [201, { round }];
    },
  });
  renderApp('/admin/campaign-rounds', { session: adminSession });

  const add = screen.getByRole('button', { name: 'Add campaign round' });
  await waitFor(() => expect(add).toBeEnabled());
  fireEvent.click(add);
  const dialog = within(screen.getByRole('dialog'));
  fireEvent.change(dialog.getByLabelText('Round name'), { target: { value: 'Synthetic Spring Round' } });
  fireEvent.change(dialog.getByLabelText('Start date'), { target: { value: '2090-02-01' } });
  fireEvent.change(dialog.getByLabelText('End date'), { target: { value: '2090-02-07' } });
  fireEvent.click(dialog.getByLabelText(/District A/));
  fireEvent.click(dialog.getByLabelText(/District B/));
  fireEvent.click(dialog.getByRole('button', { name: 'Save round' }));

  const row = (await screen.findByText('Synthetic Spring Round')).closest('tr');
  expect(row).toHaveTextContent('Area A');
  expect(row).toHaveTextContent('Area B');
  expect(round).toMatchObject({ startsOn: '2090-02-01', endsOn: '2090-02-07', areas });
});

it('shows shared rounds without offering an unauthorized edit', async () => {
  const session = { ...adminSession, user: { ...adminSession.user, role: 'supervisor', permissions: ['campaigns.manage'] } };
  mockApi({
    [`GET ${campaigns}/options`]: [200, { areas: [areas[0]] }],
    [`GET ${campaigns}`]: [200, { rounds: [{
      id: 'round-a', name: 'Synthetic Shared Round', startsOn: '2090-02-01', endsOn: '2090-02-07', areas: [areas[0]], editable: false,
    }] }],
  });
  renderApp('/admin/campaign-rounds', { session });

  const row = within((await screen.findByText('Synthetic Shared Round')).closest('tr'));
  expect(row.getByText('Area A')).toBeInTheDocument();
  expect(row.queryByRole('button', { name: /Edit|Delete/ })).not.toBeInTheDocument();
});

it('offers Nutrition Rehabilitation Centre as a referral centre type', async () => {
  const districts = [{ id: 'district-a', name: 'District A', tehsils: [] }];
  let facility;
  mockApi({
    'GET /admin/facilities/geography': [200, { districts }],
    'GET /admin/hospitals': [200, { facilities: [] }],
    'GET /admin/referral-centres': () => [200, { facilities: facility ? [facility] : [] }],
    'POST /admin/referral-centres': ({ body }) => {
      const { districtId, areaId, ...values } = JSON.parse(body);
      facility = { id: 'facility-a', ...values, district: districts.find(({ id }) => id === districtId), area: areaId };
      return [201, { facility }];
    },
  });
  renderApp('/admin/facilities', { session: adminSession });

  fireEvent.click(screen.getByRole('tab', { name: 'Referral centres' }));
  fireEvent.click(await screen.findByRole('button', { name: 'Add referral centre' }));
  const dialog = within(screen.getByRole('dialog'));
  fireEvent.click(dialog.getByRole('button', { name: 'Nutrition Rehabilitation Centre (NRC)' }));
  fireEvent.change(dialog.getByLabelText('Name'), { target: { value: 'Synthetic NRC' } });
  await dialog.findByRole('option', { name: 'District A' });
  fireEvent.change(dialog.getByLabelText('District'), { target: { value: 'district-a' } });
  fireEvent.click(dialog.getByRole('button', { name: 'Add referral centre' }));

  expect(await screen.findByText('Synthetic NRC')).toBeInTheDocument();
  expect(facility.type).toBe('Nutrition Rehabilitation Centre');
});
