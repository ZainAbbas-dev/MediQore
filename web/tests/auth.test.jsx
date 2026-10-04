import { fireEvent, screen } from '@testing-library/react';
import { mockApi, renderApp, supervisorSession } from './helpers';

jest.mock('../src/components/AreaMap', () => function AreaMapStub() {
  return <div data-testid="area-map" />;
});

function signIn(username, password) {
  fireEvent.change(screen.getByLabelText('Username'), { target: { value: username } });
  fireEvent.change(screen.getByLabelText('Password'), { target: { value: password } });
  fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));
}

describe('auth guard', () => {
  it('sends a signed-out visitor to the login page', async () => {
    renderApp('/');

    expect(await screen.findByRole('heading', { name: 'MediQore' })).toBeInTheDocument();
    expect(screen.getByLabelText('Username')).toBeInTheDocument();
  });
});

describe('login page', () => {
  it('signs a supervisor in and opens the dashboard', async () => {
    const fetchMock = mockApi({
      'POST /auth/login': [200, { accessToken: 'token-1', refreshToken: 'refresh-1', tokenType: 'Bearer', user: supervisorSession.user }],
      'GET /households': [200, { households: [] }],
    });
    renderApp('/login');

    signIn('supervisor.demo', 'demo-password');

    expect(await screen.findByRole('heading', { name: 'Dashboard' })).toBeInTheDocument();
    expect(screen.getByText('Demo Supervisor')).toBeInTheDocument();
    const [, options] = fetchMock.mock.calls[0];
    expect(JSON.parse(options.body)).toEqual({ username: 'supervisor.demo', password: 'demo-password' });
    expect(JSON.parse(sessionStorage.getItem('mediqore.session'))).toMatchObject({ token: 'token-1', refreshToken: 'refresh-1' });
  });

  it('shows a clear message for wrong credentials', async () => {
    mockApi({ 'POST /auth/login': [401, { error: { code: 'INVALID_CREDENTIALS', message: 'x' } }] });
    renderApp('/login');

    signIn('supervisor.demo', 'wrong');

    expect(await screen.findByRole('alert')).toHaveTextContent('Username or password is incorrect.');
  });

  it('keeps LHWs out of the portal', async () => {
    mockApi({
      'POST /auth/login': [200, { accessToken: 't', tokenType: 'Bearer', user: { id: 'x', role: 'lhw', fullName: 'LHW' } }],
    });
    renderApp('/login');

    signIn('lhw.demo', 'demo-password');

    expect(await screen.findByRole('alert')).toHaveTextContent('LHWs use the mobile app');
    expect(sessionStorage.getItem('mediqore.session')).toBeNull();
  });

  it('explains when the API cannot be reached', async () => {
    globalThis.fetch = jest.fn().mockRejectedValue(new TypeError('Failed to fetch'));
    renderApp('/login');

    signIn('supervisor.demo', 'demo-password');

    expect(await screen.findByRole('alert')).toHaveTextContent('Cannot reach the server');
  });
});

describe('sign out', () => {
  it('clears the session, revokes the refresh token and returns to the login page', async () => {
    const fetchMock = mockApi({ 'GET /households': [200, { households: [] }], 'POST /auth/logout': [204, {}] });
    renderApp('/', { session: supervisorSession });
    await screen.findByRole('heading', { name: 'Dashboard' });

    fireEvent.click(screen.getByRole('button', { name: 'Sign out' }));

    expect(await screen.findByLabelText('Username')).toBeInTheDocument();
    expect(sessionStorage.getItem('mediqore.session')).toBeNull();
    const logout = fetchMock.mock.calls.find(([url]) => url.endsWith('/auth/logout'));
    expect(JSON.parse(logout[1].body)).toEqual({ refreshToken: 'refresh-1' });
  });
});

describe('expired access token (M1 FE-2)', () => {
  it('refreshes the tokens once and retries the request', async () => {
    const fetchMock = mockApi({
      'GET /households': (options) => (options.headers.Authorization === 'Bearer token-2'
        ? [200, { households: [] }]
        : [401, { error: { code: 'UNAUTHORIZED', message: 'Session expired' } }]),
      'GET /women?limit=1': (options) => (options.headers.Authorization === 'Bearer token-2'
        ? [200, { women: [], total: 0 }]
        : [401, { error: { code: 'UNAUTHORIZED', message: 'Session expired' } }]),
      'POST /auth/refresh': [200, { accessToken: 'token-2', refreshToken: 'refresh-2', user: supervisorSession.user }],
    });
    renderApp('/', { session: supervisorSession });

    expect(await screen.findByText('No households have been synced yet.')).toBeInTheDocument();
    // Both dashboard requests got 401 at once; they share one refresh.
    expect(fetchMock.mock.calls.filter(([url]) => url.endsWith('/auth/refresh'))).toHaveLength(1);
    const refresh = fetchMock.mock.calls.find(([url]) => url.endsWith('/auth/refresh'));
    expect(JSON.parse(refresh[1].body)).toEqual({ refreshToken: 'refresh-1' });
    expect(JSON.parse(sessionStorage.getItem('mediqore.session'))).toMatchObject({ token: 'token-2', refreshToken: 'refresh-2' });
  });

  it('signs out when the refresh token no longer works', async () => {
    mockApi({
      'GET /households': [401, { error: { code: 'UNAUTHORIZED', message: 'Session expired' } }],
      'POST /auth/refresh': [401, { error: { code: 'INVALID_REFRESH_TOKEN', message: 'Sign in again' } }],
    });
    renderApp('/', { session: supervisorSession });

    expect(await screen.findByLabelText('Username')).toBeInTheDocument();
    expect(sessionStorage.getItem('mediqore.session')).toBeNull();
  });
});
