const db = require('../db/pool');

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// The account behind a token, or null if it no longer exists. Deactivated
// accounts are returned with isActive false, so the caller can refuse them
// with a clear reason (M1 FE-3: refused at their next request).
async function findById(id) {
  if (typeof id !== 'string' || !UUID.test(id)) return null;
  const { rows } = await db.query(
    'SELECT id, role, full_name, is_active FROM users WHERE id = $1 AND deleted_at IS NULL',
    [id],
  );
  if (!rows.length) return null;
  return { id: rows[0].id, role: rows[0].role, fullName: rows[0].full_name, isActive: rows[0].is_active };
}

// What the app and the portal need to know about the signed-in user. For an
// LHW this includes the LHW ID and area, so the app can tell when the area changes.
async function profile(client, userId) {
  const { rows: [row] } = await client.query(
    `SELECT u.id, u.username, u.role, u.full_name, p.lhw_code, p.area_id, a.name AS area_name
     FROM users u
     LEFT JOIN lhw_profiles p ON p.user_id = u.id AND p.deleted_at IS NULL
     LEFT JOIN areas a ON a.id = p.area_id
     WHERE u.id = $1`,
    [userId],
  );
  const result = { id: row.id, username: row.username, role: row.role, fullName: row.full_name };
  if (row.role === 'lhw') {
    Object.assign(result, { lhwCode: row.lhw_code, areaId: row.area_id, areaName: row.area_name });
  }
  return result;
}

module.exports = { findById, profile };
