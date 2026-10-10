const crypto = require('node:crypto');
const bcrypt = require('bcryptjs');
const config = require('../config');

// M1 FE-2: one-time activation codes and the per-phone activation secret.
//
// - An admin generates an activation code for an LHW: random, 8 characters
//   (shown as XXXX-XXXX), valid 48 hours, usable once, stored only as a bcrypt
//   hash. A new code cancels the LHW's earlier unused ones.
// - At activation the server gives the phone a secret. The phone keeps it in
//   the Android Keystore and uses it, offline, to check the reply code a
//   supervisor reads out when the LHW has forgotten her PIN.
// - The server never stores the secret. It derives it from a server key and a
//   random reference kept in devices.activation_secret_ref, so a database leak
//   alone does not reveal it.

// No look-alike characters (0/O, 1/I/L), so a code read aloud is not mistyped.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 8;
const HOUR_MS = 60 * 60 * 1000;

function newCode() {
  return Array.from({ length: CODE_LENGTH }, () => CODE_ALPHABET[crypto.randomInt(CODE_ALPHABET.length)]).join('');
}

// "k7qm-4r2x", "K7QM 4R2X" and "K7QM4R2X" are the same code.
function normaliseCode(code) {
  return String(code).toUpperCase().replace(/[\s-]/g, '');
}

const formatCode = (code) => `${code.slice(0, 4)}-${code.slice(4)}`;

// Cancels the user's unused codes (a newer code or a deactivation).
async function revokeOpenCodes(client, userId) {
  await client.query(
    'UPDATE activation_codes SET revoked_at = now() WHERE user_id = $1 AND consumed_at IS NULL AND revoked_at IS NULL',
    [userId],
  );
}

// Issues a code for an LHW and returns it once, formatted, with its expiry.
async function issueCode(client, { userId, issuedBy }) {
  await revokeOpenCodes(client, userId);
  const code = newCode();
  const expiresAt = new Date(Date.now() + config.activation.codeTtlHours * HOUR_MS);
  const { rows: [row] } = await client.query(
    `INSERT INTO activation_codes (user_id, code_hash, issued_by, expires_at)
     VALUES ($1, $2, $3, $4) RETURNING id`,
    [userId, await bcrypt.hash(code, 10), issuedBy, expiresAt],
  );
  return { id: row.id, code: formatCode(code), expiresAt };
}

// Finds the LHW's open code that matches, or null. It does not mark it used.
async function findValidCode(client, userId, code) {
  const typed = normaliseCode(code);
  const { rows } = await client.query(
    `SELECT id, code_hash FROM activation_codes
     WHERE user_id = $1 AND consumed_at IS NULL AND revoked_at IS NULL AND expires_at > now()
     ORDER BY created_at DESC
     FOR UPDATE`,
    [userId],
  );
  for (const row of rows) {
    if (await bcrypt.compare(typed, row.code_hash)) return row;
  }
  return null;
}

async function consumeCode(client, codeId, deviceId) {
  await client.query('UPDATE activation_codes SET consumed_at = now(), device_id = $2 WHERE id = $1', [codeId, deviceId]);
}

// The key the activation secrets are derived from: PIN_RESET_SECRET if set,
// otherwise derived from the JWT secret, so no extra setting is required.
function serverKey() {
  if (config.activation.pinResetSecret) return Buffer.from(config.activation.pinResetSecret, 'utf8');
  return Buffer.from(crypto.hkdfSync('sha256', config.jwt.accessSecret, Buffer.alloc(0), 'mediqore/pin-reset', 32));
}

const newSecretRef = () => crypto.randomBytes(16).toString('base64url');

// The phone's activation secret (32 bytes) for its ID and reference.
function deviceSecret(deviceId, secretRef) {
  return crypto.createHmac('sha256', serverKey()).update(`mediqore/activation/${deviceId}/${secretRef}`).digest();
}

// The 8-digit reply to the 6-digit code a phone shows when its PIN is forgotten.
// The app computes the same value from its stored secret (mobile/lib/auth/pin_reset.dart).
function replyCode(secret, challenge) {
  const digest = crypto.createHmac('sha256', secret).update(`mediqore/pin-reset/${challenge}`).digest();
  return String(digest.readUInt32BE(0) % 100_000_000).padStart(8, '0');
}

module.exports = {
  revokeOpenCodes,
  CODE_ALPHABET,
  CODE_LENGTH,
  newCode,
  normaliseCode,
  formatCode,
  issueCode,
  findValidCode,
  consumeCode,
  newSecretRef,
  deviceSecret,
  replyCode,
};
