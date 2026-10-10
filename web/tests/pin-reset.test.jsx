import { fireEvent, screen, within } from '@testing-library/react';
import { adminSession, mockApi, renderApp, supervisorSession } from './helpers';

jest.mock('../src/components/AreaMap', () => function AreaMapStub() {
  return <div data-testid="area-map" />;
});

const filters = {
  districts: [],
  unionCouncils: [],
  lhws: [{ id: 'l1', lhwCode: 'LHW-00007', fullName: 'Sana Iqbal', unionCouncilId: 'u', districtId: 'd' }],
};

const reply = {
  replyCode: '26434093',
  lhw: { id: 'l1', fullName: 'Sana Iqbal', lhwCode: 'LHW-00007' },
  device: { model: 'Tecno Spark', activatedAt: '2026-10-04T08:00:00.000Z' },
};

async function ask(challenge) {
  const lhwSelect = await screen.findByLabelText('LHW');
  await screen.findByRole('option', { name: 'LHW-00007 · Sana Iqbal' });
  fireEvent.change(lhwSelect, { target: { value: 'l1' } });
  fireEvent.change(screen.getByLabelText('Code on her phone'), { target: { value: challenge } });
  fireEvent.click(screen.getByRole('button', { name: 'Get reply code' }));
}

describe('PIN reset codes (M1 FE-2)', () => {
  it('gives the supervisor the reply code for the code on the phone, once', async () => {
    const fetchMock = mockApi({
      'GET /dashboard/filters': [200, filters],
      'POST /pin-reset/reply-code': [200, reply],
    });
    renderApp('/pin-reset', { session: supervisorSession });

    await ask('483 917');

    const notice = await screen.findByRole('region', { name: 'Reply code' });
    expect(within(notice).getByText('26434093')).toBeInTheDocument();
    expect(within(notice).getByText(/Tecno Spark/)).toBeInTheDocument();
    const call = fetchMock.mock.calls.find(([url]) => url.endsWith('/pin-reset/reply-code'));
    expect(JSON.parse(call[1].body)).toEqual({ lhwId: 'l1', challenge: '483917' });

    fireEvent.click(within(notice).getByRole('button', { name: 'Done' }));
    expect(screen.queryByText('26434093')).not.toBeInTheDocument();
  });

  it('says when the LHW has no activated phone', async () => {
    mockApi({
      'GET /dashboard/filters': [200, filters],
      'POST /pin-reset/reply-code': [404, { error: { code: 'NO_ACTIVATED_PHONE', message: 'This LHW has no activated phone' } }],
    });
    renderApp('/pin-reset', { session: adminSession });

    await ask('483917');

    expect(await screen.findByRole('alert')).toHaveTextContent('needs a new activation code');
  });
});

describe('navigation by role', () => {
  it('shows LHW accounts to admins only, PIN reset codes to both', async () => {
    mockApi({ 'GET /households': [200, { households: [] }] });
    const { unmount } = renderApp('/', { session: adminSession });
    expect(await screen.findByRole('link', { name: 'LHW accounts' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'PIN reset codes' })).toBeInTheDocument();
    unmount();
    sessionStorage.clear();

    renderApp('/', { session: supervisorSession });
    expect(await screen.findByRole('link', { name: 'PIN reset codes' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'LHW accounts' })).not.toBeInTheDocument();
  });

  it('keeps supervisors out of the admin page', async () => {
    mockApi({});
    renderApp('/admin/lhws', { session: supervisorSession });

    expect(await screen.findByRole('heading', { name: 'Not available' })).toBeInTheDocument();
  });
});
