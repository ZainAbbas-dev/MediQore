const bcrypt = require('bcryptjs');
const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { writeAudit } = require('./audit.service');
const tokens = require('./tokens.service');
const { newPassword } = require('./lhws.service');

// M10 FE-3: supervisor and admin accounts, managed by admins on the portal
// (LHW accounts are in lhws.service, M1 FE-1). The admin chooses the username;
// the password is random, shown once and stored only as a bcrypt hash. A
// supervisor sees the areas assigned here (supervisor_areas). An admin cannot
// lock themselves out: they cannot deactivate or demote their own account, and
// the last active admin stays an admin. Every change writes an audit row.

const STAFF_SQL = `
  SELECT u.id, u.role, u.username, u.full_name, u.phone, u.is_active, u.last_login_at, u.created_at,
         coalesce(json_agg(json_build_object(
           'id', a.id, 'name', a.name, 'unionCouncil', uc.name, 'tehsil', t.name, 'district', d.name
         ) ORDER BY d.name, t.name, uc.name, a.name) FILTER (WHERE a.id IS NOT NULL), '[]') AS areas
  FROM users u
  LEFT JOIN supervisor_areas s ON s.supervisor_id = u.id AND s.deleted_at IS NULL
  LEFT JOIN areas a ON a.id = s.area_id
  LEFT JOIN union_councils uc ON uc.id = a.union_council_id
  LEFT JOIN tehsils t ON t.id = uc.tehsil_id
  LEFT JOIN districts d ON d.id = t.district_id
  WHERE u.role IN ('supervisor', 'admin') AND u.deleted_at IS NULL`;

function toStaff(row) {
  return {
    id: row.id,
    role: row.role,
    username: row.username,
    fullName: row.full_name,
    phone: row.phone,
    isActive: row.is_active,
    lastLoginAt: row.last_login_at,
    createdAt: row.created_at,
    areas: row.areas,
  };
}

async function findStaff(client, id) {
  const { rows: [row] } = await client.query(`${STAFF_SQL} AND u.id = $1 GROUP BY u.id`, [id]);
  if (!row) throw new AppError(404, 'NOT_FOUND', 'No supervisor or admin with this ID');
  return row;
}

async function lockStaff(client, id) {
  const { rows: [row] } = await client.query(
    "SELECT id FROM users WHERE id = $1 AND role IN ('supervisor', 'admin') AND deleted_at IS NULL FOR UPDATE",
    [id],
  );
  if (!row) throw new AppError(404, 'NOT_FOUND', 'No supervisor or admin with this ID');
  return findStaff(client, id);
}

async function requireAreas(client, areaIds) {
  const { rows: [{ n }] } = await client.query(
    'SELECT count(*)::int AS n FROM areas WHERE id = ANY($1) AND deleted_at IS NULL',
    [areaIds],
  );
  if (n !== new Set(areaIds).size) throw new AppError(400, 'UNKNOWN_AREA', 'One of these areas does not exist');
}

// Replaces a supervisor's areas; returns whether anything changed.
async function setAreas(client, userId, areaIds) {
  const wanted = [...new Set(areaIds)];
  const { rows } = await client.query(
    'SELECT area_id FROM supervisor_areas WHERE supervisor_id = $1 AND deleted_at IS NULL',
    [userId],
  );
  const current = rows.map((r) => r.area_id);
  const removed = current.filter((id) => !wanted.includes(id));
  const added = wanted.filter((id) => !current.includes(id));
  if (removed.length) {
    await client.query(
      'UPDATE supervisor_areas SET deleted_at = now() WHERE supervisor_id = $1 AND area_id = ANY($2) AND deleted_at IS NULL',
      [userId, removed],
    );
  }
  for (const areaId of added) {
    await client.query('INSERT INTO supervisor_areas (supervisor_id, area_id) VALUES ($1, $2)', [userId, areaId]);
  }
  return removed.length || added.length ? { added, removed } : null;
}

// Refuses a change that would leave no active admin.
async function keepOneAdmin(client, id) {
  const { rows: [{ n }] } = await client.query(
    "SELECT count(*)::int AS n FROM users WHERE role = 'admin' AND is_active AND deleted_at IS NULL AND id <> $1",
    [id],
  );
  if (n === 0) throw new AppError(409, 'LAST_ADMIN', 'At least one active admin account must remain');
}

// GET /admin/staff
async function list({ search, role, status }) {
  const params = [];
  let sql = STAFF_SQL;
  if (search) {
    params.push(`%${search.toLowerCase()}%`);
    sql += ` AND (lower(u.full_name) LIKE $${params.length} OR lower(u.username) LIKE $${params.length})`;
  }
  if (role) {
    params.push(role);
    sql += ` AND u.role = $${params.length}`;
  }
  if (status === 'active') sql += ' AND u.is_active';
  if (status === 'inactive') sql += ' AND NOT u.is_active';
  const { rows } = await db.query(`${sql} GROUP BY u.id ORDER BY u.role DESC, lower(u.username)`, params);
  return { staff: rows.map(toStaff) };
}

// POST /admin/staff
async function create(admin, { role, username, fullName, phone, areaIds = [] }) {
  if (role === 'supervisor' && areaIds.length === 0) {
    throw new AppError(400, 'AREAS_REQUIRED', 'A supervisor needs at least one area');
  }
  return db.withTransaction(async (client) => {
    const { rowCount: taken } = await client.query('SELECT 1 FROM users WHERE lower(username) = lower($1)', [username]);
    if (taken) throw new AppError(409, 'USERNAME_TAKEN', 'This username is already used');
    if (role === 'supervisor') await requireAreas(client, areaIds);
    const password = newPassword();
    const { rows: [user] } = await client.query(
      `INSERT INTO users (role, username, full_name, phone, password_hash)
       VALUES ($1, $2, $3, $4, $5) RETURNING id`,
      [role, username, fullName, phone || null, await bcrypt.hash(password, 10)],
    );
    if (role === 'supervisor') await setAreas(client, user.id, areaIds);
    await writeAudit(client, {
      userId: admin.id, action: 'create', entityType: 'users', entityId: user.id,
      details: { role, username, ...(role === 'supervisor' ? { areaIds } : {}) },
    });
    return { staff: toStaff(await findStaff(client, user.id)), credentials: { username, password } };
  });
}

// PATCH /admin/staff/:id: name, phone, role and areas.
async function update(admin, id, changes) {
  return db.withTransaction(async (client) => {
    const before = await lockStaff(client, id);
    const changed = {};
    const role = changes.role ?? before.role;

    if (role !== before.role) {
      if (id === admin.id) throw new AppError(409, 'OWN_ACCOUNT', 'You cannot change the role of your own account');
      if (before.role === 'admin') await keepOneAdmin(client, id);
      await client.query('UPDATE users SET role = $2 WHERE id = $1', [id, role]);
      // Signs them out, so the new role applies from their next sign-in.
      await tokens.revokeAllForUser(client, id);
      changed.role = { from: before.role, to: role };
    }
    if (changes.fullName !== undefined && changes.fullName !== before.full_name) {
      await client.query('UPDATE users SET full_name = $2 WHERE id = $1', [id, changes.fullName]);
      changed.fullName = { from: before.full_name, to: changes.fullName };
    }
    if (changes.phone !== undefined && (changes.phone || null) !== before.phone) {
      await client.query('UPDATE users SET phone = $2 WHERE id = $1', [id, changes.phone || null]);
      changed.phone = { from: before.phone, to: changes.phone || null };
    }

    // A supervisor keeps their areas unless new ones are given; an admin has none.
    const areaIds = role === 'admin' ? [] : changes.areaIds ?? before.areas.map((a) => a.id);
    if (role === 'supervisor' && areaIds.length === 0) {
      throw new AppError(400, 'AREAS_REQUIRED', 'A supervisor needs at least one area');
    }
    if (role === 'supervisor') await requireAreas(client, areaIds);
    const areas = await setAreas(client, id, areaIds);
    if (areas) changed.areaIds = areas;

    if (Object.keys(changed).length) {
      await writeAudit(client, { userId: admin.id, action: 'edit', entityType: 'users', entityId: id, details: { changes: changed } });
    }
    return { staff: toStaff(await findStaff(client, id)) };
  });
}

// POST /admin/staff/:id/deactivate and /activate
async function setActive(admin, id, active) {
  return db.withTransaction(async (client) => {
    const before = await lockStaff(client, id);
    if (before.is_active !== active) {
      if (!active && id === admin.id) throw new AppError(409, 'OWN_ACCOUNT', 'You cannot deactivate your own account');
      if (!active && before.role === 'admin') await keepOneAdmin(client, id);
      await client.query('UPDATE users SET is_active = $2 WHERE id = $1', [id, active]);
      if (!active) await tokens.revokeAllForUser(client, id);
      await writeAudit(client, {
        userId: admin.id, action: 'edit', entityType: 'users', entityId: id, details: { change: active ? 'activate' : 'deactivate' },
      });
    }
    return { staff: toStaff(await findStaff(client, id)) };
  });
}

// POST /admin/staff/:id/reset-password
async function resetPassword(admin, id) {
  return db.withTransaction(async (client) => {
    const before = await lockStaff(client, id);
    const password = newPassword();
    await client.query('UPDATE users SET password_hash = $2 WHERE id = $1', [id, await bcrypt.hash(password, 10)]);
    await tokens.revokeAllForUser(client, id);
    await writeAudit(client, { userId: admin.id, action: 'edit', entityType: 'users', entityId: id, details: { change: 'password_reset' } });
    return { staff: toStaff(await findStaff(client, id)), credentials: { username: before.username, password } };
  });
}

module.exports = { list, create, update, setActive, resetPassword };
