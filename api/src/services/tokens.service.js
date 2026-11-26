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
function signAccessToken(user, deviceId, sessionExpiresAt) {
  const claims = { role: user.role };
  if (deviceId) claims.did = deviceId;
  const options = { subject: user.id, algorithm: 'HS256' };
  const token = jwt.sign(claims, config.jwt.accessSecret, {
    ...options,
    expiresIn: config.jwt.accessExpiresIn,
    mutatePayload: true,
  });
  // Keep the configured JWT lifetime except near the absolute deadline.
  const deadline = Math.floor(sessionExpiresAt.getTime() / 1000);
  if (claims.exp <= deadline) return token;
  claims.exp = deadline;
  return jwt.sign(claims, config.jwt.accessSecret, { algorithm: options.algorithm });
}

async function issueRefreshToken(client, userId, deviceId, sessionExpiresAt) {
  const token = crypto.randomBytes(32).toString('base64url');
  const expiresAt = sessionExpiresAt ?? new Date(Date.now() + config.refreshTokenTtlDays * DAY_MS);
  await client.query(
    'INSERT INTO refresh_tokens (user_id, device_id, token_hash, expires_at) VALUES ($1, $2, $3, $4)',
    [userId, deviceId || null, hashToken(token), expiresAt],
  );
  return { token, expiresAt };
}

// Revokes the presented refresh token and returns its owner, ready for a new
// pair (link the new token with linkReplacement). Fails with 401 if the token
// is unknown, expired, revoked or its phone was revoked.
//
// One exception keeps a phone signed in on a weak network (M3 FE-2): a replaced
// token is accepted again as long as its replacement has never been used,
// because the phone then never received the answer (the network dropped, or the
// phone gave up while a sleeping server was starting). The phone may try again
// days later, up to the original session deadline. The unused replacement is
// revoked instead. Once the replacement has been used the old token is dead.
// Sign-out, deactivation and a password reset revoke the replacement too.
async function consumeRefreshToken(client, token) {
  const { rows: [row] } = await client.query(
    `SELECT t.id, t.user_id, t.device_id, t.expires_at, t.revoked_at, t.replaced_by,
            u.is_active, d.revoked_at AS device_revoked_at,
            r.revoked_at AS replacement_revoked_at
     FROM refresh_tokens t
     JOIN users u ON u.id = t.user_id AND u.deleted_at IS NULL
     LEFT JOIN devices d ON d.id = t.device_id
     LEFT JOIN refresh_tokens r ON r.id = t.replaced_by
     WHERE t.token_hash = $1
     FOR UPDATE OF t`,
    [hashToken(token)],
  );
  const invalid = new AppError(401, 'INVALID_REFRESH_TOKEN', 'Sign in again');
  if (!row || row.device_revoked_at) throw invalid;
  // The phone refreshes before syncing, so it must see this status even when
  // account deactivation has already revoked its refresh token.
  if (!row.is_active) throw new AppError(403, 'ACCOUNT_INACTIVE', 'This account has been deactivated');
  if (row.expires_at <= new Date()) throw invalid;
  if (row.revoked_at) {
    const lostReplacement = row.replaced_by && row.replacement_revoked_at === null;
    if (!lostReplacement) throw invalid;
    const { rowCount } = await client.query(
      'UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1 AND revoked_at IS NULL',
      [row.replaced_by],
    );
    if (rowCount === 0) throw invalid; // used at the same moment by another request
  } else {
    await client.query('UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1', [row.id]);
  }
  return { userId: row.user_id, deviceId: row.device_id, tokenId: row.id, expiresAt: row.expires_at };
}

// Records which token replaced the one consumed, for consumeRefreshToken.
async function linkReplacement(client, tokenId, newToken) {
  await client.query(
    'UPDATE refresh_tokens SET replaced_by = (SELECT id FROM refresh_tokens WHERE token_hash = $2) WHERE id = $1',
    [tokenId, hashToken(newToken)],
  );
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

module.exports = {
  signAccessToken, issueRefreshToken, consumeRefreshToken, linkReplacement, revokeRefreshToken, revokeAllForUser, hashToken,
};
