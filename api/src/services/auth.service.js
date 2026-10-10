const bcrypt = require('bcryptjs');
const config = require('../config');
const db = require('../db/pool');
const AppError = require('../utils/app-error');
const activation = require('./activation.service');
const { writeAudit } = require('./audit.service');
const { loginThrottle, LoginThrottle } = require('./login-throttle');
const tokens = require('./tokens.service');
const usersService = require('./users.service');

// M1 FE-2: sign-in for the app and the portal.
// - Password check with bcrypt, rate-limited per client address and username.
// - The app is for LHWs. The first sign-in on a phone is online, with the
//   username, password and the one-time activation code an admin generated
//   (POST /auth/activate). The phone then gets its activation secret (for the
//   offline PIN reset) and its tokens; from then on the LHW unlocks it offline
//   with her PIN, and the app uses the tokens only to sync.
// - On an activated phone the password alone signs in again (POST /auth/login),
//   for example after a password reset revoked the tokens. Any other phone gets
//   ACTIVATION_REQUIRED. Supervisors and admins sign in on the portal.
// - Success returns a short-lived access token and a refresh token; for an
//   LHW also the phone numbers of her area's supervisors, for the lock
//   screen's emergency call.
// Every sign-in attempt, activation and sign-out writes an audit row (M10 FE-3).

// Compared against when the username does not exist, so a wrong username takes
// as long as a wrong password and does not reveal which accounts exist.
const DUMMY_HASH = bcrypt.hashSync('no-such-user', 10);

const INVALID = () => new AppError(401, 'INVALID_CREDENTIALS', 'Username or password is incorrect');
const INACTIVE = () => new AppError(403, 'ACCOUNT_INACTIVE', 'This account has been deactivated');
const DEVICE_NOT_ALLOWED = () =>
  new AppError(403, 'DEVICE_NOT_ALLOWED', 'This phone is registered to another account or has been blocked');
const ACTIVATION_REQUIRED = () =>
  new AppError(403, 'ACTIVATION_REQUIRED', 'This phone is not activated. Ask your admin for an activation code.');
const CODE_INVALID = () =>
  new AppError(400, 'ACTIVATION_CODE_INVALID', 'The activation code is wrong, used or expired. Ask your admin for a new one.');
const APP_FOR_LHWS = () => new AppError(403, 'APP_FOR_LHWS', 'The app is for LHWs; supervisors and admins use the portal');

// Checks the password, counting failures for rate limiting. Returns the user row.
async function checkPassword(username, password, throttleKey, deviceId) {
  loginThrottle.check(throttleKey);
  const { rows: [user] } = await db.query(
    `SELECT id, role, full_name, password_hash, is_active FROM users
     WHERE lower(username) = lower($1) AND deleted_at IS NULL`,
    [username],
  );
  const passwordOk = await bcrypt.compare(password, user ? user.password_hash : DUMMY_HASH);

  if (!user || !passwordOk) {
    loginThrottle.fail(throttleKey);
    await writeAudit(db, {
      userId: user ? user.id : null,
      action: 'login',
      entityType: 'users',
      entityId: user ? user.id : null,
      details: { result: 'failed', reason: user ? 'wrong_password' : 'unknown_user', ...(deviceId && { deviceId }) },
    });
    throw INVALID();
  }

  loginThrottle.succeed(throttleKey);
  if (!user.is_active) {
    await writeAudit(db, {
      userId: user.id, action: 'login', entityType: 'users', entityId: user.id,
      details: { result: 'failed', reason: 'inactive', ...(deviceId && { deviceId }) },
    });
    throw INACTIVE();
  }
  return user;
}

// The supervisors of an LHW's area with a phone number, for the emergency call
// on the lock screen.
async function supervisorsFor(client, userId) {
  const { rows } = await client.query(
    `SELECT DISTINCT s.full_name, s.phone
     FROM lhw_profiles p
     JOIN supervisor_areas sa ON sa.area_id = p.area_id AND sa.deleted_at IS NULL
     JOIN users s ON s.id = sa.supervisor_id AND s.is_active AND s.deleted_at IS NULL
     WHERE p.user_id = $1 AND p.deleted_at IS NULL AND s.phone IS NOT NULL AND s.phone <> ''
     ORDER BY s.full_name`,
    [userId],
  );
  return rows.map((row) => ({ name: row.full_name, phone: row.phone }));
}

// Tokens and profile for a signed-in user.
async function sessionBody(client, user, deviceId) {
  const refresh = await tokens.issueRefreshToken(client, user.id, deviceId);
  const body = {
    status: 'ok',
    accessToken: tokens.signAccessToken(user, deviceId),
    tokenType: 'Bearer',
    expiresIn: config.jwt.accessExpiresIn,
    refreshToken: refresh.token,
    refreshExpiresAt: refresh.expiresAt.toISOString(),
    user: await usersService.profile(client, user.id),
  };
  if (user.role === 'lhw') body.supervisors = await supervisorsFor(client, user.id);
  return body;
}

async function startSession(client, user, deviceId, result = 'success') {
  await client.query('UPDATE users SET last_login_at = now() WHERE id = $1', [user.id]);
  if (deviceId) await client.query('UPDATE devices SET last_seen_at = now() WHERE id = $1', [deviceId]);
  await writeAudit(client, {
    userId: user.id, deviceId: deviceId || null, action: 'login', entityType: 'users', entityId: user.id,
    details: { result },
  });
  return sessionBody(client, user, deviceId);
}

async function auditRefusal(client, user, deviceId, reason) {
  await writeAudit(client, {
    userId: user.id, action: 'login', entityType: 'users', entityId: user.id,
    details: { result: 'failed', reason, deviceId },
  });
}

// POST /auth/activate: the first sign-in on a phone. Consumes the activation
// code, marks the phone activated and returns its activation secret once.
async function activate({ username, password, activationCode, deviceId, deviceModel }, { ip }) {
  const throttleKey = LoginThrottle.key(ip, username);
  const user = await checkPassword(username, password, throttleKey, deviceId);
  if (user.role !== 'lhw') throw APP_FOR_LHWS();

  const outcome = await db.withTransaction(async (client) => {
    const { rows: [existing] } = await client.query('SELECT user_id, revoked_at FROM devices WHERE id = $1 FOR UPDATE', [deviceId]);
    if (existing && (existing.user_id !== user.id || existing.revoked_at)) {
      await auditRefusal(client, user, deviceId, existing.revoked_at ? 'device_revoked' : 'device_of_another_user');
      return { error: 'DEVICE' };
    }
    const code = await activation.findValidCode(client, user.id, activationCode);
    if (!code) {
      await auditRefusal(client, user, deviceId, 'activation_code_invalid');
      return { error: 'CODE' };
    }

    const secretRef = activation.newSecretRef();
    await client.query(
      `INSERT INTO devices (id, user_id, model, activated_at, activation_secret_ref, last_seen_at)
       VALUES ($1, $2, $3, now(), $4, now())
       ON CONFLICT (id) DO UPDATE SET model = coalesce(EXCLUDED.model, devices.model), activated_at = now(),
         activation_secret_ref = EXCLUDED.activation_secret_ref, last_seen_at = now()`,
      [deviceId, user.id, deviceModel || null, secretRef],
    );
    await activation.consumeCode(client, code.id, deviceId);
    const body = await startSession(client, user, deviceId, 'activated');
    return { ...body, activationSecret: activation.deviceSecret(deviceId, secretRef).toString('base64url') };
  });

  if (outcome.error === 'DEVICE') throw DEVICE_NOT_ALLOWED();
  if (outcome.error === 'CODE') {
    loginThrottle.fail(throttleKey);
    throw CODE_INVALID();
  }
  return outcome;
}

// POST /auth/login: the portal (supervisors and admins, no phone) or an
// already activated phone signing in again with the password.
async function login({ username, password, deviceId }, { ip }) {
  const user = await checkPassword(username, password, LoginThrottle.key(ip, username), deviceId);

  if (user.role === 'lhw' && !deviceId) {
    throw new AppError(400, 'DEVICE_REQUIRED', 'LHWs sign in with the MediQore app');
  }
  if (!deviceId) {
    return db.withTransaction((client) => startSession(client, user, null));
  }
  if (user.role !== 'lhw') throw APP_FOR_LHWS();

  const outcome = await db.withTransaction(async (client) => {
    const { rows: [device] } = await client.query(
      'SELECT user_id, activated_at, revoked_at FROM devices WHERE id = $1',
      [deviceId],
    );
    if (device && (device.user_id !== user.id || device.revoked_at)) {
      await auditRefusal(client, user, deviceId, device.revoked_at ? 'device_revoked' : 'device_of_another_user');
      return 'blocked';
    }
    if (!device || !device.activated_at) {
      await auditRefusal(client, user, deviceId, 'not_activated');
      return 'not_activated';
    }
    return startSession(client, user, deviceId);
  });
  if (outcome === 'blocked') throw DEVICE_NOT_ALLOWED();
  if (outcome === 'not_activated') throw ACTIVATION_REQUIRED();
  return outcome;
}

// POST /auth/refresh: swaps a refresh token for a new pair.
async function refresh({ refreshToken }) {
  return db.withTransaction(async (client) => {
    const { userId, deviceId } = await tokens.consumeRefreshToken(client, refreshToken);
    const user = await usersService.findById(userId);
    if (!user) throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'Sign in again');
    if (!user.isActive) throw INACTIVE();
    return sessionBody(client, user, deviceId);
  });
}

// POST /auth/logout: revokes the refresh token.
async function logout({ refreshToken }) {
  await db.withTransaction(async (client) => {
    const owner = await tokens.revokeRefreshToken(client, refreshToken);
    if (owner) {
      await writeAudit(client, {
        userId: owner.userId, deviceId: owner.deviceId, action: 'login', entityType: 'users', entityId: owner.userId,
        details: { result: 'logout' },
      });
    }
  });
}

module.exports = { activate, login, refresh, logout, supervisorsFor };
