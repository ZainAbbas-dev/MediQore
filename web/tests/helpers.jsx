import { render } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import App from '../src/App';
import AuthProvider from '../src/auth/AuthProvider';

// Renders the whole portal at `path`, optionally already signed in.
export function renderApp(path = '/', { session } = {}) {
  if (session) sessionStorage.setItem('mediqore.session', JSON.stringify(session));
  return render(
    <MemoryRouter initialEntries={[path]}>
      <AuthProvider>
        <App />
      </AuthProvider>
    </MemoryRouter>,
  );
}

export const supervisorSession = {
  token: 'token-1',
  refreshToken: 'refresh-1',
  user: { id: '6f1c2b8e-4d3a-4f5b-9c7d-2e1a0b9c8d7e', role: 'supervisor', fullName: 'Demo Supervisor' },
};

export const adminSession = {
  token: 'admin-token',
  refreshToken: 'admin-refresh',
  user: { id: '0d4f6a2b-7c1e-4a9b-8d3f-5e2c1b0a9f8e', role: 'admin', fullName: 'Demo Admin' },
};

const json = (status, body) => ({
  ok: status < 400,
  status,
  statusText: String(status),
  text: async () => JSON.stringify(body),
});

// Replaces fetch with fake API answers: routes maps "METHOD /path" to
// [status, body], or to a function (options) => [status, body] for answers
// that change, for example a 401 before a token refresh.
export function mockApi(routes) {
  const fetchMock = jest.fn(async (url, options = {}) => {
    const key = `${options.method || 'GET'} ${url.replace('/api/v1', '')}`;
    const route = routes[key];
    if (!route) return json(404, { error: { code: 'NOT_FOUND', message: `No mock for ${key}` } });
    return json(...(typeof route === 'function' ? route(options) : route));
  });
  globalThis.fetch = fetchMock;
  return fetchMock;
}
