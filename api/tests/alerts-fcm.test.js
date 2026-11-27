const { generateKeyPairSync } = require('node:crypto');
const jwt = require('jsonwebtoken');
const { createFcmSender, fcmSettings, escalationMinutes } = require('../src/services/alerts-fcm.service');

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const settings = {
  projectId: 'synthetic-project',
  clientEmail: 'synthetic@example.invalid',
  privateKey,
};

test('requires all server-side Firebase settings and accepts a configurable escalation limit', () => {
  expect(fcmSettings({ FIREBASE_PROJECT_ID: 'synthetic-project' })).toBeNull();
  expect(fcmSettings({
    FIREBASE_PROJECT_ID: 'synthetic-project',
    FIREBASE_CLIENT_EMAIL: 'synthetic@example.invalid',
    FIREBASE_PRIVATE_KEY: 'first\\nsecond',
  })).toEqual({ ...settings, privateKey: 'first\nsecond' });
  expect(escalationMinutes({})).toBe(15);
  expect(escalationMinutes({ ALERT_ESCALATION_MINUTES: '7' })).toBe(7);
  expect(escalationMinutes({ ALERT_ESCALATION_MINUTES: '-1' })).toBe(15);
});

test('exchanges a signed OAuth assertion once and sends only a data payload to each token', async () => {
  const fakeFetch = jest.fn()
    .mockResolvedValueOnce({ ok: true, json: async () => ({ access_token: 'synthetic-bearer', expires_in: 3600 }) })
    .mockResolvedValue({ ok: true });
  const send = createFcmSender(settings, { fetch: fakeFetch });
  const data = { title: 'Emergency alert', body: 'Open the MediQore portal for details.', url: '/alerts' };
  await Promise.all([send('browser-one', data), send('browser-two', data)]);

  const [[oauthUrl, oauth], ...messages] = fakeFetch.mock.calls;
  expect(oauthUrl).toBe('https://oauth2.googleapis.com/token');
  expect(oauth.method).toBe('POST');
  expect(oauth.body.get('grant_type')).toBe('urn:ietf:params:oauth:grant-type:jwt-bearer');
  expect(jwt.verify(oauth.body.get('assertion'), publicKey, { algorithms: ['RS256'] })).toMatchObject({
    iss: 'synthetic@example.invalid',
    aud: 'https://oauth2.googleapis.com/token',
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  });
  expect(messages).toHaveLength(2);
  for (const [index, [url, options]] of messages.entries()) {
    expect(url).toBe('https://fcm.googleapis.com/v1/projects/synthetic-project/messages:send');
    expect(options.headers.Authorization).toBe('Bearer synthetic-bearer');
    expect(JSON.parse(options.body)).toEqual({
      message: { token: ['browser-one', 'browser-two'][index], data, webpush: { headers: { Urgency: 'high' } } },
    });
  }
});

test('identifies an unregistered token without treating it as accepted by FCM', async () => {
  const fakeFetch = jest.fn()
    .mockResolvedValueOnce({ ok: true, json: async () => ({ access_token: 'synthetic-bearer', expires_in: 3600 }) })
    .mockResolvedValueOnce({
      ok: false,
      status: 404,
      json: async () => ({ error: { details: [{ errorCode: 'UNREGISTERED' }] } }),
    });
  const send = createFcmSender(settings, { fetch: fakeFetch });
  await expect(send('stale-browser', { title: 'Emergency alert' })).resolves.toEqual({ unregistered: true });
});
