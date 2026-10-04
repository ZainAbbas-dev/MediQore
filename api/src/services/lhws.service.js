const crypto = require('node:crypto');
const bcrypt = require('bcryptjs');
const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { writeAudit } = require('./audit.service');
const tokens = require('./tokens.service');

// M1 FE-1, FE-3: LHW accounts, managed by admins on the portal.
// - Creating an LHW issues a unique LHW ID (LHW-00001, ...), which is also the
//   username, and a random password. The password is shown to the admin once
//   and stored only as a bcrypt hash.
// - Admins can rename, reassign the area, deactivate or reactivate an LHW, and
//   reset the password. Deactivation and a password reset revoke the LHW's
//   refresh tokens, so the phone is refused at its next sync.
// Every change writes an audit row with the admin as the user (M10 FE-3).

// No look-alike characters (0/O, 1/l/I), so a password read aloud or copied by
// hand is not mistyped.
const PASSWORD_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
const PASSWORD_LENGTH = 10;

function newPassword() {
  return Array.from({ length: PASSWORD_LENGTH }, () => PASSWORD_ALPHABET[crypto.randomInt(PASSWORD_ALPHABET.length)]).join('');
}

const LHW_SQL = `
  SELECT u.id, u.username, u.full_name, u.phone, u.is_active, u.last_login_at, u.created_at,
         p.lhw_code, p.area_id, a.name AS area_name,
         uc.id AS union_council_id, uc.name AS union_council_name,
         t.id AS tehsil_id, t.name AS tehsil_name,
         d.id AS district_id, d.name AS district_name,
         (SELECT count(*)::int FROM devices v WHERE v.user_id = u.id AND v.verified_at IS NOT NULL AND v.revoked_at IS NULL) AS approved_devices,
         (SELECT count(*)::int FROM devices v WHERE v.user_id = u.id AND v.verified_at IS NULL AND v.revoked_at IS NULL) AS pending_devices
  FROM users u
  JOIN lhw_profiles p ON p.user_id = u.id AND p.deleted_at IS NULL
  JOIN areas a ON a.id = p.area_id
  JOIN union_councils uc ON uc.id = a.union_council_id
  JOIN tehsils t ON t.id = uc.tehsil_id
  JOIN districts d ON d.id = t.district_id
  WHERE u.role = 'lhw' AND u.deleted_at IS NULL`;

function toLhw(row) {
  return {
    id: row.id,
    lhwCode: row.lhw_code,
    username: row.username,
    fullName: row.full_name,
    phone: row.phone,
    isActive: row.is_active,
    lastLoginAt: row.last_login_at,
    createdAt: row.created_at,
    area: {
      id: row.area_id,
      name: row.area_name,
      unionCouncil: { id: row.union_council_id, name: row.union_council_name },
      tehsil: { id: row.tehsil_id, name: row.tehsil_name },
      district: { id: row.district_id, name: row.district_name },
    },
    devices: { approved: row.approved_devices, pending: row.pending_devices },
  };
}

async function findLhw(client, id, { lock = false } = {}) {
  const { rows: [row] } = await client.query(`${LHW_SQL} AND u.id = $1${lock ? ' FOR UPDATE OF u' : ''}`, [id]);
  if (!row) throw new AppError(404, 'NOT_FOUND', 'No LHW with this ID');
  return row;
}

async function requireArea(client, areaId) {
  const { rowCount } = await client.query('SELECT 1 FROM areas WHERE id = $1 AND deleted_at IS NULL', [areaId]);
  if (!rowCount) throw new AppError(400, 'UNKNOWN_AREA', 'This area does not exist');
}

// GET /admin/lhws
async function list({ search, areaId, status }) {
  const params = [];
  let sql = LHW_SQL;
  if (search) {
    params.push(`%${search.toLowerCase()}%`);
    sql += ` AND (lower(u.full_name) LIKE $${params.length} OR lower(p.lhw_code) LIKE $${params.length})`;
  }
  if (areaId) {
    params.push(areaId);
    sql += ` AND p.area_id = $${params.length}`;
  }
  if (status === 'active') sql += ' AND u.is_active';
  if (status === 'inactive') sql += ' AND NOT u.is_active';
  const { rows } = await db.query(`${sql} ORDER BY p.lhw_code`, params);
  return { lhws: rows.map(toLhw) };
}

// POST /admin/lhws
async function create(admin, { fullName, areaId, phone }) {
  return db.withTransaction(async (client) => {
    await requireArea(client, areaId);
    const { rows: [{ n }] } = await client.query("SELECT nextval('lhw_code_seq') AS n");
    const lhwCode = `LHW-${String(n).padStart(5, '0')}`;
    const password = newPassword();
    const { rows: [user] } = await client.query(
      `INSERT INTO users (role, username, full_name, phone, password_hash)
       VALUES ('lhw', $1, $2, $3, $4) RETURNING id`,
      [lhwCode, fullName, phone || null, await bcrypt.hash(password, 10)],
    );
    await client.query('INSERT INTO lhw_profiles (user_id, lhw_code, area_id) VALUES ($1, $2, $3)', [user.id, lhwCode, areaId]);
    await writeAudit(client, {
      userId: admin.id, action: 'create', entityType: 'users', entityId: user.id,
      details: { role: 'lhw', lhwCode, areaId },
    });
    return { lhw: toLhw(await findLhw(client, user.id)), credentials: { username: lhwCode, password } };
  });
}

// PATCH /admin/lhws/:id: name, phone and area (reassignment).
async function update(admin, id, changes) {
  return db.withTransaction(async (client) => {
    const before = await findLhw(client, id, { lock: true });
    const changed = {};
    if (changes.fullName !== undefined && changes.fullName !== before.full_name) {
      await client.query('UPDATE users SET full_name = $2 WHERE id = $1', [id, changes.fullName]);
      changed.fullName = { from: before.full_name, to: changes.fullName };
    }
    if (changes.phone !== undefined && (changes.phone || null) !== before.phone) {
      await client.query('UPDATE users SET phone = $2 WHERE id = $1', [id, changes.phone || null]);
      changed.phone = { from: before.phone, to: changes.phone || null };
    }
    if (changes.areaId !== undefined && changes.areaId !== before.area_id) {
      await requireArea(client, changes.areaId);
      await client.query('UPDATE lhw_profiles SET area_id = $2, updated_at = now() WHERE user_id = $1', [id, changes.areaId]);
      changed.areaId = { from: before.area_id, to: changes.areaId };
    }
    if (Object.keys(changed).length) {
      await writeAudit(client, { userId: admin.id, action: 'edit', entityType: 'users', entityId: id, details: { changes: changed } });
    }
    return { lhw: toLhw(await findLhw(client, id)) };
  });
}

// POST /admin/lhws/:id/deactivate and /activate
async function setActive(admin, id, active) {
  return db.withTransaction(async (client) => {
    const before = await findLhw(client, id, { lock: true });
    if (before.is_active !== active) {
      await client.query('UPDATE users SET is_active = $2 WHERE id = $1', [id, active]);
      if (!active) await tokens.revokeAllForUser(client, id);
      await writeAudit(client, {
        userId: admin.id, action: 'edit', entityType: 'users', entityId: id,
        details: { change: active ? 'activate' : 'deactivate' },
      });
    }
    return { lhw: toLhw(await findLhw(client, id)) };
  });
}

// POST /admin/lhws/:id/reset-password. The portal warns first that unsynced
// data on the phone becomes unreadable (LI-8).
async function resetPassword(admin, id) {
  return db.withTransaction(async (client) => {
    const before = await findLhw(client, id, { lock: true });
    const password = newPassword();
    await client.query('UPDATE users SET password_hash = $2 WHERE id = $1', [id, await bcrypt.hash(password, 10)]);
    await tokens.revokeAllForUser(client, id);
    await writeAudit(client, { userId: admin.id, action: 'edit', entityType: 'users', entityId: id, details: { change: 'password_reset' } });
    return { lhw: toLhw(await findLhw(client, id)), credentials: { username: before.username, password } };
  });
}

// GET /admin/areas: every area with its Union Council, tehsil and district, for pickers.
async function listAreas() {
  const { rows } = await db.query(
    `SELECT a.id, a.name, uc.name AS union_council, t.name AS tehsil, d.name AS district
     FROM areas a
     JOIN union_councils uc ON uc.id = a.union_council_id
     JOIN tehsils t ON t.id = uc.tehsil_id
     JOIN districts d ON d.id = t.district_id
     WHERE a.deleted_at IS NULL
     ORDER BY d.name, t.name, uc.name, a.name`,
  );
  return {
    areas: rows.map((r) => ({ id: r.id, name: r.name, unionCouncil: r.union_council, tehsil: r.tehsil, district: r.district })),
  };
}

module.exports = { list, create, update, setActive, resetPassword, listAreas, newPassword };
