const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const config = require('../config');
const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { writeAudit } = require('./audit.service');

// Compared against when the username does not exist, so a wrong username takes
// as long as a wrong password and does not reveal which accounts exist.
const DUMMY_HASH = bcrypt.hashSync('no-such-user', 10);

const INVALID = () => new AppError(401, 'INVALID_CREDENTIALS', 'Username or password is incorrect');

// M1 FE-2 (Phase 0 skeleton): password login that returns a short-lived JWT
// access token. Refresh tokens, OTP and login rate limiting come in Phase 1.
async function login(username, password) {
  const { rows } = await db.query(
    `SELECT id, role, full_name, password_hash, is_active FROM users
     WHERE lower(username) = lower($1) AND deleted_at IS NULL`,
    [username],
  );
  const user = rows[0];
  const passwordOk = await bcrypt.compare(password, user ? user.password_hash : DUMMY_HASH);

  if (!user || !passwordOk || !user.is_active) {
    const reason = !user ? 'unknown_user' : !passwordOk ? 'wrong_password' : 'inactive';
    await writeAudit(db, {
      userId: user ? user.id : null,
      action: 'login',
      entityType: 'users',
      entityId: user ? user.id : null,
      details: { result: 'failed', reason },
    });
    throw INVALID();
  }

  await db.withTransaction(async (client) => {
    await client.query('UPDATE users SET last_login_at = now() WHERE id = $1', [user.id]);
    await writeAudit(client, {
      userId: user.id,
      action: 'login',
      entityType: 'users',
      entityId: user.id,
      details: { result: 'success' },
    });
  });

  const accessToken = jwt.sign({ role: user.role }, config.jwt.accessSecret, {
    subject: user.id,
    expiresIn: config.jwt.accessExpiresIn,
    algorithm: 'HS256',
  });

  return {
    accessToken,
    tokenType: 'Bearer',
    expiresIn: config.jwt.accessExpiresIn,
    user: { id: user.id, role: user.role, fullName: user.full_name },
  };
}

module.exports = { login };
