const jwt = require('jsonwebtoken');

const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const MESSAGING_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

function fcmSettings(env = process.env) {
  const { FIREBASE_PROJECT_ID: projectId, FIREBASE_CLIENT_EMAIL: clientEmail, FIREBASE_PRIVATE_KEY: privateKey } = env;
  if (!projectId || !clientEmail || !privateKey) return null;
  return { projectId, clientEmail, privateKey: privateKey.replace(/\\n/g, '\n') };
}

function escalationMinutes(env = process.env) {
  const parsed = Number(env.ALERT_ESCALATION_MINUTES);
  return Number.isInteger(parsed) && parsed > 0 && parsed <= 2147483647 ? parsed : 15;
}

function createFcmSender(settings, { fetch: fetchRequest = globalThis.fetch } = {}) {
  const { projectId, clientEmail, privateKey } = settings;
  const sendUrl = `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`;
  let accessToken;
  let expiresAt = 0;
  let requesting;

  async function refresh() {
    const assertion = jwt.sign({ scope: MESSAGING_SCOPE }, privateKey, {
      algorithm: 'RS256', issuer: clientEmail, audience: GOOGLE_TOKEN_URL, expiresIn: '1h',
    });
    const res = await fetchRequest(GOOGLE_TOKEN_URL, {
      method: 'POST',
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) throw new Error('FCM authentication failed');
    const data = await res.json();
    if (!data.access_token) throw new Error('FCM authentication returned no access token');
    accessToken = data.access_token;
    expiresAt = Date.now() + (data.expires_in - 60) * 1000;
    return accessToken;
  }

  async function token() {
    if (accessToken && Date.now() < expiresAt) return accessToken;
    requesting ??= refresh().finally(() => { requesting = undefined; });
    return requesting;
  }

  return async function send(registrationToken, data) {
    const res = await fetchRequest(sendUrl, {
      method: 'POST',
      headers: { Authorization: `Bearer ${await token()}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token: registrationToken,
          data,
          webpush: { headers: { Urgency: 'high' } },
        },
      }),
      signal: AbortSignal.timeout(5000),
    });
    if (res.ok) return;
    if (res.status === 401) expiresAt = 0;
    const body = await res.json().catch(() => null);
    const unregistered = body?.error?.details?.some((detail) => detail.errorCode === 'UNREGISTERED');
    if (unregistered) return { unregistered: true };
    throw new Error('FCM message send failed');
  };
}

module.exports = { fcmSettings, escalationMinutes, createFcmSender };
