const db = require('../db/pool');

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// The signed-in user, or null if the account no longer exists or has been
// deactivated (M1 FE-3: deactivated accounts are refused at their next request).
async function findActiveById(id) {
  if (typeof id !== 'string' || !UUID.test(id)) return null;
  const { rows } = await db.query(
    `SELECT id, role, full_name FROM users
     WHERE id = $1 AND is_active AND deleted_at IS NULL`,
    [id],
  );
  if (!rows.length) return null;
  return { id: rows[0].id, role: rows[0].role, fullName: rows[0].full_name };
}

module.exports = { findActiveById };
