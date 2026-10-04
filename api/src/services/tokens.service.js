const crypto = require('node:crypto');
const jwt = require('jsonwebtoken');
const config = require('../config');
const AppError = require('../utils/app-error');

// M1 FE-2: a short-lived JWT access token plus a longer-lived refresh token.
// Refresh tokens are random strings stored only as a SHA-256 hash, so they can
// be revoked (on sign-out, deactivation or password reset) and a database leak
// does not reveal usable tokens. Each use replaces the token with a new one.

const DAY_MS = 24 * 60 * 60 * 1000;
const hashToken = (token) => crypto.createHash('sha256').update(token).digest('hex');

// The access token carries the role and, for app sign-ins, the phone (`did`),
// so sync requests can be tied to the verified device they came from.
function signAccessToken(user, deviceId) {
  const claims = { role: user.role };
  if (deviceId) claims.did = deviceId;
  return jwt.sign(claims, config.jwt.accessSecret, {
    subject: user.id,
    expiresIn: config.jwt.accessExpiresIn,
    algorithm: 'HS256',
  });
}

async function issueRefreshToken(client, userId, deviceId) {
  const token = crypto.randomBytes(32).toString('base64url');
  const expiresAt = new Date(Date.now() + config.refreshTokenTtlDays * DAY_MS);
  await client.query(
    'INSERT INTO refresh_tokens (user_id, device_id, token_hash, expires_at) VALUES ($1, $2, $3, $4)',
    [userId, deviceId || null, hashToken(token), expiresAt],
  );
  return { token, expiresAt };
}

// Revokes the presented refresh token and returns its owner, ready for a new
// pair. Fails with 401 if the token is unknown, expired, revoked or its phone
// was revoked.
async function consumeRefreshToken(client, token) {
  const { rows: [row] } = await client.query(
    `SELECT t.id, t.user_id, t.device_id, t.expires_at, t.revoked_at, d.revoked_at AS device_revoked_at
     FROM refresh_tokens t LEFT JOIN devices d ON d.id = t.device_id
     WHERE t.token_hash = $1
     FOR UPDATE OF t`,
    [hashToken(token)],
  );
  if (!row || row.revoked_at || row.device_revoked_at || row.expires_at <= new Date()) {
    throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'Sign in again');
  }
  await client.query('UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1', [row.id]);
  return { userId: row.user_id, deviceId: row.device_id };
}

// Revokes one token (sign-out). Unknown tokens are ignored.
async function revokeRefreshToken(client, token) {
  const { rows } = await client.query(
    'UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = $1 AND revoked_at IS NULL RETURNING user_id, device_id',
    [hashToken(token)],
  );
  return rows[0] ? { userId: rows[0].user_id, deviceId: rows[0].device_id } : null;
}

// Revokes every refresh token of a user, for deactivation and password reset.
async function revokeAllForUser(client, userId) {
  await client.query('UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL', [userId]);
}

module.exports = { signAccessToken, issueRefreshToken, consumeRefreshToken, revokeRefreshToken, revokeAllForUser, hashToken };
