const crypto = require('node:crypto');
const bcrypt = require('bcryptjs');
const config = require('../config');

// M1 FE-2, decision 0002: one-time codes that approve a new phone. The
// prototype has one channel, `admin_issued`: an admin or supervisor issues the
// code on the portal and hands it to the user. Email or an SMS gateway
// (production, LI-4) would be another channel behind the same two functions,
// with no change to the login flow or the otp_codes table.
const CHANNEL = 'admin_issued';
const HOUR_MS = 60 * 60 * 1000;

const newCode = () => String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');

// Issues a fresh code for a pending phone. Older unused codes for the same
// phone stop working. Returns the code once; only its hash is stored.
async function issue(client, { userId, deviceId }) {
  await client.query(
    'UPDATE otp_codes SET expires_at = now() WHERE device_id = $1 AND consumed_at IS NULL AND expires_at > now()',
    [deviceId],
  );
  const { rows: [{ verified }] } = await client.query(
    'SELECT count(*)::int AS verified FROM devices WHERE user_id = $1 AND verified_at IS NOT NULL',
    [userId],
  );
  const purpose = verified ? 'new_device' : 'first_login';
  const code = newCode();
  const expiresAt = new Date(Date.now() + config.otp.ttlHours * HOUR_MS);
  const { rows: [row] } = await client.query(
    `INSERT INTO otp_codes (user_id, device_id, purpose, channel, code_hash, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
    [userId, deviceId, purpose, CHANNEL, await bcrypt.hash(code, 10), expiresAt],
  );
  return { id: row.id, code, expiresAt, purpose, channel: CHANNEL };
}

// Checks a code typed on the phone. Returns { ok: true } and marks the code
// used, or { ok: false, reason } with reason NOT_ISSUED (no valid code),
// INVALID (wrong code) or LOCKED (too many wrong tries, the code is now void).
// It never throws for a wrong code, so the caller can commit the counted
// attempt before refusing the request.
async function verify(client, { userId, deviceId, code }) {
  const { rows: [row] } = await client.query(
    `SELECT id, code_hash, attempts FROM otp_codes
     WHERE user_id = $1 AND device_id = $2 AND consumed_at IS NULL AND expires_at > now()
     ORDER BY created_at DESC LIMIT 1
     FOR UPDATE`,
    [userId, deviceId],
  );
  if (!row) return { ok: false, reason: 'NOT_ISSUED' };

  if (await bcrypt.compare(code, row.code_hash)) {
    await client.query('UPDATE otp_codes SET consumed_at = now() WHERE id = $1', [row.id]);
    return { ok: true, id: row.id };
  }

  const attempts = row.attempts + 1;
  const locked = attempts >= config.otp.maxAttempts;
  await client.query(
    `UPDATE otp_codes SET attempts = $2, expires_at = CASE WHEN $3::boolean THEN now() ELSE expires_at END WHERE id = $1`,
    [row.id, attempts, locked],
  );
  return { ok: false, reason: locked ? 'LOCKED' : 'INVALID' };
}

module.exports = { issue, verify, CHANNEL };
