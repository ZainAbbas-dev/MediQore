const bcrypt = require('bcryptjs');
const config = require('../config');
const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { writeAudit } = require('./audit.service');
const { loginThrottle, LoginThrottle } = require('./login-throttle');
const otp = require('./otp.service');
const tokens = require('./tokens.service');
const usersService = require('./users.service');

// M1 FE-2: sign-in for the app and the portal.
// - Password check with bcrypt, rate-limited per client address and username.
// - The app signs in with its phone's installation ID. A phone that has not
//   been approved gets "otp_required" until the user types the one-time code an
//   admin or supervisor issued for it (decision 0002). LHWs can sign in only
//   through the app; the portal is for supervisors and admins.
// - Success returns a short-lived access token and a refresh token.
// Every sign-in attempt, code check and sign-out writes an audit row (M10 FE-3).

// Compared against when the username does not exist, so a wrong username takes
// as long as a wrong password and does not reveal which accounts exist.
const DUMMY_HASH = bcrypt.hashSync('no-such-user', 10);

const INVALID = () => new AppError(401, 'INVALID_CREDENTIALS', 'Username or password is incorrect');
const INACTIVE = () => new AppError(403, 'ACCOUNT_INACTIVE', 'This account has been deactivated');
const DEVICE_NOT_ALLOWED = () =>
  new AppError(403, 'DEVICE_NOT_ALLOWED', 'This phone is registered to another account or has been blocked');

const OTP_ERRORS = {
  NOT_ISSUED: () => new AppError(400, 'OTP_NOT_ISSUED', 'There is no valid code for this phone. Ask your supervisor or admin for one.'),
  INVALID: () => new AppError(400, 'OTP_INVALID', 'The code is not correct'),
  LOCKED: () => new AppError(400, 'OTP_LOCKED', 'Too many wrong codes. Ask your supervisor or admin for a new one.'),
};

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

// Registers the phone on its first sign-in and returns its state. A phone
// belongs to one account; a blocked phone stays blocked.
async function registerDevice(client, user, deviceId, deviceModel) {
  const { rows: [device] } = await client.query(
    `INSERT INTO devices (id, user_id, model, last_seen_at) VALUES ($1, $2, $3, now())
     ON CONFLICT (id) DO UPDATE SET last_seen_at = now(), model = coalesce(EXCLUDED.model, devices.model)
       WHERE devices.user_id = EXCLUDED.user_id
     RETURNING verified_at, revoked_at`,
    [deviceId, user.id, deviceModel || null],
  );
  if (!device || device.revoked_at) {
    await writeAudit(client, {
      userId: user.id, action: 'login', entityType: 'users', entityId: user.id,
      details: { result: 'failed', reason: device ? 'device_revoked' : 'device_of_another_user', deviceId },
    });
    return 'blocked';
  }
  return device.verified_at ? 'verified' : 'pending';
}

// Tokens and profile for a signed-in user.
async function sessionBody(client, user, deviceId) {
  const refresh = await tokens.issueRefreshToken(client, user.id, deviceId);
  return {
    status: 'ok',
    accessToken: tokens.signAccessToken(user, deviceId),
    tokenType: 'Bearer',
    expiresIn: config.jwt.accessExpiresIn,
    refreshToken: refresh.token,
    refreshExpiresAt: refresh.expiresAt.toISOString(),
    user: await usersService.profile(client, user.id),
  };
}

async function startSession(client, user, deviceId, result = 'success') {
  await client.query('UPDATE users SET last_login_at = now() WHERE id = $1', [user.id]);
  await writeAudit(client, {
    userId: user.id, deviceId: deviceId || null, action: 'login', entityType: 'users', entityId: user.id,
    details: { result },
  });
  return sessionBody(client, user, deviceId);
}

// POST /auth/login
async function login({ username, password, deviceId, deviceModel }, { ip }) {
  const user = await checkPassword(username, password, LoginThrottle.key(ip, username), deviceId);

  if (user.role === 'lhw' && !deviceId) {
    throw new AppError(400, 'DEVICE_REQUIRED', 'LHWs sign in with the MediQore app');
  }
  if (!deviceId) {
    return db.withTransaction((client) => startSession(client, user, null));
  }

  const outcome = await db.withTransaction(async (client) => {
    const state = await registerDevice(client, user, deviceId, deviceModel);
    if (state === 'pending') {
      await writeAudit(client, {
        userId: user.id, deviceId, action: 'login', entityType: 'users', entityId: user.id,
        details: { result: 'otp_required' },
      });
      return { status: 'otp_required', otp: { channel: otp.CHANNEL } };
    }
    if (state === 'verified') return startSession(client, user, deviceId);
    return state;
  });
  if (outcome === 'blocked') throw DEVICE_NOT_ALLOWED();
  return outcome;
}

// POST /auth/otp/verify: the password again plus the code issued for this phone.
async function verifyOtp({ username, password, deviceId, code }, { ip }) {
  const throttleKey = LoginThrottle.key(ip, username);
  const user = await checkPassword(username, password, throttleKey, deviceId);

  const outcome = await db.withTransaction(async (client) => {
    const { rows: [device] } = await client.query(
      'SELECT verified_at, revoked_at FROM devices WHERE id = $1 AND user_id = $2 FOR UPDATE',
      [deviceId, user.id],
    );
    if (!device) return { error: 'NOT_ISSUED' };
    if (device.revoked_at) return { error: 'BLOCKED' };
    if (device.verified_at) return startSession(client, user, deviceId);

    const check = await otp.verify(client, { userId: user.id, deviceId, code });
    if (!check.ok) {
      await writeAudit(client, {
        userId: user.id, deviceId, action: 'login', entityType: 'otp_codes', entityId: null,
        details: { result: 'failed', reason: `otp_${check.reason.toLowerCase()}` },
      });
      return { error: check.reason }; // commits the counted attempt
    }
    await client.query('UPDATE devices SET verified_at = now() WHERE id = $1', [deviceId]);
    return startSession(client, user, deviceId, 'device_verified');
  });

  if (outcome.error === 'BLOCKED') throw DEVICE_NOT_ALLOWED();
  if (outcome.error) {
    loginThrottle.fail(throttleKey);
    throw OTP_ERRORS[outcome.error]();
  }
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

module.exports = { login, verifyOtp, refresh, logout };
