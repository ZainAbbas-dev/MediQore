const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { writeAudit } = require('./audit.service');
const { supervisorAreaIds } = require('./scope.service');
const otp = require('./otp.service');

// M1 FE-2, decision 0002: phones waiting for approval and the one-time codes
// that approve them. An admin sees every pending phone. A supervisor sees, and
// can issue codes for, the LHWs in their own areas only.

const PENDING_SQL = `
  SELECT d.id, d.model, d.created_at, d.last_seen_at,
         u.id AS user_id, u.username, u.full_name, u.role,
         p.lhw_code, p.area_id, a.name AS area_name,
         (SELECT max(o.expires_at) FROM otp_codes o
           WHERE o.device_id = d.id AND o.consumed_at IS NULL AND o.expires_at > now()) AS code_expires_at
  FROM devices d
  JOIN users u ON u.id = d.user_id AND u.is_active AND u.deleted_at IS NULL
  LEFT JOIN lhw_profiles p ON p.user_id = u.id AND p.deleted_at IS NULL
  LEFT JOIN areas a ON a.id = p.area_id
  WHERE d.verified_at IS NULL AND d.revoked_at IS NULL`;

// Supervisors are limited to LHWs in their areas; admins see everyone.
async function scopeFilter(client, viewer, params) {
  if (viewer.role === 'admin') return '';
  params.push(await supervisorAreaIds(client, viewer.id));
  return ` AND u.role = 'lhw' AND p.area_id = ANY($${params.length})`;
}

function toPendingDevice(row) {
  return {
    id: row.id,
    model: row.model,
    firstSeenAt: row.created_at,
    lastSeenAt: row.last_seen_at,
    codeExpiresAt: row.code_expires_at,
    user: {
      id: row.user_id,
      username: row.username,
      fullName: row.full_name,
      role: row.role,
      lhwCode: row.lhw_code,
      areaName: row.area_name,
    },
  };
}

// GET /devices/pending
async function listPending(viewer) {
  const params = [];
  const filter = await scopeFilter(db, viewer, params);
  const { rows } = await db.query(`${PENDING_SQL}${filter} ORDER BY d.created_at DESC`, params);
  return { devices: rows.map(toPendingDevice) };
}

// POST /devices/:id/code: issues a one-time code and returns it once.
async function issueCode(viewer, deviceId) {
  return db.withTransaction(async (client) => {
    const params = [deviceId];
    const filter = await scopeFilter(client, viewer, params);
    const { rows: [row] } = await client.query(`${PENDING_SQL} AND d.id = $1${filter} FOR UPDATE OF d`, params);
    if (!row) throw new AppError(404, 'NOT_FOUND', 'No pending phone with this ID in your areas');

    const issued = await otp.issue(client, { userId: row.user_id, deviceId });
    // Never log the code itself.
    await writeAudit(client, {
      userId: viewer.id, action: 'create', entityType: 'otp_codes', entityId: issued.id,
      details: { deviceId, forUser: row.user_id, purpose: issued.purpose, channel: issued.channel },
    });
    return { code: issued.code, expiresAt: issued.expiresAt, purpose: issued.purpose, device: toPendingDevice(row) };
  });
}

module.exports = { listPending, issueCode };
