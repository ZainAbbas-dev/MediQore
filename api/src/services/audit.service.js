const db = require('../db/pool');

// M10 FE-3: every create, edit, delete, referral, alert and login writes an audit
// row. Pass the transaction's client so the audit row commits or rolls back
// together with the change it describes.
async function writeAudit(client, { userId = null, deviceId = null, action, entityType = null, entityId = null, details = {} }) {
  await client.query(
    `INSERT INTO audit_log (user_id, device_id, action, entity_type, entity_id, details)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [userId, deviceId, action, entityType, entityId, details],
  );
}

const ACTIONS = ['create', 'edit', 'delete', 'referral', 'alert', 'login', 'sync_conflict'];

// GET /admin/audit: the audit log viewer, newest first, filtered by user (part
// of a username or name), action, record type and dates. Dates are whole days,
// Pakistan time. Pages go back with `before`, the last row's id.
async function list({ user, action, entityType, from, to, before, limit }) {
  const params = [];
  const where = ['true'];
  const add = (value, condition) => {
    params.push(value);
    where.push(condition.replaceAll('?', `$${params.length}`));
  };
  if (user) add(`%${user.toLowerCase()}%`, '(lower(u.username) LIKE ? OR lower(u.full_name) LIKE ?)');
  if (action) add(action, 'l.action = ?');
  if (entityType) add(entityType, 'l.entity_type = ?');
  if (from) add(from, "l.occurred_at >= (?::date)::timestamp AT TIME ZONE 'Asia/Karachi'");
  if (to) add(to, "l.occurred_at < (?::date + 1)::timestamp AT TIME ZONE 'Asia/Karachi'");
  if (before) add(before, 'l.id < ?');
  params.push(limit + 1);
  const { rows } = await db.query(
    `SELECT l.id, l.occurred_at, l.action, l.entity_type, l.entity_id, l.device_id, l.details,
            u.id AS user_id, u.username, u.full_name, u.role,
            eu.username AS entity_username
     FROM audit_log l
     LEFT JOIN users u ON u.id = l.user_id
     LEFT JOIN users eu ON l.entity_type = 'users' AND eu.id = l.entity_id
     WHERE ${where.join(' AND ')}
     ORDER BY l.id DESC
     LIMIT $${params.length}`,
    params,
  );
  const page = rows.slice(0, limit);
  return {
    entries: page.map((row) => ({
      id: Number(row.id),
      occurredAt: row.occurred_at,
      action: row.action,
      entityType: row.entity_type,
      entityId: row.entity_id,
      // For accounts, the username, so the row reads without looking it up.
      entityLabel: row.entity_username,
      deviceId: row.device_id,
      details: row.details,
      user: row.user_id ? { id: row.user_id, username: row.username, fullName: row.full_name, role: row.role } : null,
    })),
    nextBefore: rows.length > limit ? Number(page[page.length - 1].id) : null,
  };
}

// The record types that appear in the log, for the viewer's filter.
async function entityTypes() {
  const { rows } = await db.query('SELECT DISTINCT entity_type FROM audit_log WHERE entity_type IS NOT NULL ORDER BY 1');
  return rows.map((row) => row.entity_type);
}

module.exports = { writeAudit, list, entityTypes, ACTIONS };
