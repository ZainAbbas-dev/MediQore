import { fireEvent, render, screen, within } from '@testing-library/react';
import { AuthContext } from '../src/auth/context';
import AlertsPage from '../src/pages/AlertsPage';

const emergency = {
  id: 'a1',
  type: 'emergency',
  patient: { name: 'Synthetic woman', patientCode: 'SYN-001' },
  areaName: 'Area A',
  occurredAt: '2026-10-01T09:30:00.000Z',
  status: 'open',
  attempts: [{ channel: 'sms', recipient: 'secondary', status: 'sent', attemptedAt: '2026-10-01T09:35:00.000Z' }],
  overdue: true,
  escalationSeconds: 900,
  reminder: { status: 'sent', attemptedAt: '2026-10-01T09:45:00.000Z' },
};
const modelRed = {
  id: 'r1',
  type: 'model_red',
  patient: { name: 'Synthetic high risk', patientCode: 'SYN-002' },
  areaName: 'Area A',
  occurredAt: '2026-10-01T10:30:00.000Z',
  status: null,
};

test('shows the channel and resend for an emergency and acknowledges only that emergency', async () => {
  const acknowledgement = { method: 'dashboard', acknowledgedAt: '2026-10-01T10:00:00.000Z' };
  const acknowledged = { ...emergency, status: 'acknowledged', acknowledgement };
  const request = jest.fn(async (_path, options) => options?.method === 'POST'
    ? { alert: acknowledged }
    : { alerts: [emergency, modelRed], nextBefore: null, pushAvailable: false });
  render(
    <AuthContext.Provider value={{ request, user: { role: 'supervisor', permissions: ['alerts.acknowledge'] } }}>
      <AlertsPage />
    </AuthContext.Provider>,
  );

  const urgent = await screen.findByRole('article', { name: /SYN-001/ });
  expect(urgent).toHaveTextContent('Unacknowledged');
  expect(urgent).toHaveTextContent('SMS');
  expect(urgent).toHaveTextContent('15 min');
  expect(urgent).toHaveTextContent('Push reminder sent');
  const high = screen.getByRole('article', { name: /SYN-002/ });
  expect(high).toHaveTextContent('High-risk case');
  expect(within(high).queryByRole('button', { name: 'Acknowledge' })).toBeNull();

  fireEvent.click(within(urgent).getByRole('button', { name: 'Acknowledge' }));
  expect(await within(urgent).findByText('Acknowledged')).toBeInTheDocument();
  expect(request).toHaveBeenCalledWith('/alerts/a1/acknowledge', { method: 'POST' });
});

test('shows a data-only FCM notification and opens only a same-origin portal page', async () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const vm = require('node:vm');
  const routes = {};
  const worker = {
    location: { origin: 'https://portal.example' },
    addEventListener: (name, listener) => { routes[name] = listener; },
    registration: { showNotification: jest.fn(() => Promise.resolve()) },
    clients: { matchAll: async () => [], openWindow: jest.fn() },
  };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../public/sw.js'), 'utf8'), { self: worker, URL });
  let promise;
  const waitUntil = (task) => { promise = task; };

  routes.push({
    data: { json: () => ({ fcmMessageId: 'envelope', data: { title: 'Emergency alert', url: '/alerts' } }) },
    waitUntil,
  });
  await promise;
  expect(worker.registration.showNotification).toHaveBeenCalledWith('Emergency alert', expect.objectContaining({
    data: { url: '/alerts' },
  }));

  routes.notificationclick({
    notification: { close: () => {}, data: { url: 'https://external.example/' } },
    waitUntil,
  });
  await promise;
  expect(worker.clients.openWindow).toHaveBeenCalledWith('https://portal.example/alerts');
});
