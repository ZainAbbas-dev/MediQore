const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { writeAudit } = require('./audit.service');
const { supervisorAreaIds } = require('./scope.service');
const { insertRecord } = require('./sync.service');
const { TABLES, normalise } = require('../sync/tables');

// M3 FE-2, M10 base: the supervisor's sync conflict queue. A visit that arrived
// for a pregnancy that already had a visit on the same day is held here (see
// sync.service) until a supervisor of that area, or an admin, decides:
//   keep_both      both visits are real: the held one is stored as well;
//   keep_existing  the held one is a duplicate: it is stored as deleted, so it
//                  stays on record and the phone that sent it drops it;
//   keep_incoming  the held one replaces the earlier visit, which is deleted.
// Nothing is overwritten, and every step writes an audit row (LI-7).

const RESOLUTIONS = ['keep_both', 'keep_existing', 'keep_incoming'];

// Supervisors are limited to their areas; admins see every area.
async function scopeFilter(client, viewer, params) {
  if (viewer.role === 'admin') return '';
  params.push(await supervisorAreaIds(client, viewer.id));
  return ` AND c.area_id = ANY($${params.length})`;
}

// A stored row in the shape the device sent it (camelCase fields).
function recordData(table, row) {
  const def = TABLES[table];
  return Object.fromEntries(Object.entries(def.fields).map(([name, field]) => [name, normalise(field, row[field.column])]));
}

const LIST_SQL = `
  SELECT c.*, a.name AS area_name,
         su.full_name AS submitted_by_name, sp.lhw_code AS submitted_by_code,
         ru.full_name AS resolved_by_name,
         w.name AS woman_name, w.patient_code,
         to_jsonb(e.*) AS existing_row
  FROM sync_conflicts c
  JOIN areas a ON a.id = c.area_id
  LEFT JOIN users su ON su.id = c.submitted_by
  LEFT JOIN lhw_profiles sp ON sp.user_id = c.submitted_by
  LEFT JOIN users ru ON ru.id = c.resolved_by
  LEFT JOIN visits e ON c.table_name = 'visits' AND e.id = c.existing_record_id
  LEFT JOIN pregnancies p ON p.id = e.pregnancy_id
  LEFT JOIN women w ON w.id = p.woman_id
  WHERE true`;

function toConflict(row) {
  const incoming = row.incoming_payload;
  const existing = row.existing_row;
  return {
    id: row.id,
    table: row.table_name,
    reason: row.reason,
    status: row.status,
    resolution: row.resolution,
    createdAt: row.created_at,
    resolvedAt: row.resolved_at,
    resolvedBy: row.resolved_by_name,
    areaId: row.area_id,
    areaName: row.area_name,
    submittedBy: { lhwCode: row.submitted_by_code, fullName: row.submitted_by_name },
    woman: row.patient_code ? { name: row.woman_name, patientCode: row.patient_code } : null,
    incoming: { id: incoming.id, data: incoming.data },
    existing: existing
      ? { id: existing.id, deleted: existing.deleted_at !== null, data: recordData(row.table_name, existing) }
      : null,
  };
}

// GET /conflicts?status=pending|resolved|all
async function list(viewer, { status }) {
  const params = [];
  let sql = LIST_SQL + (await scopeFilter(db, viewer, params));
  if (status !== 'all') {
    params.push(status);
    sql += ` AND c.status = $${params.length}`;
  }
  const { rows } = await db.query(`${sql} ORDER BY c.created_at DESC LIMIT 200`, params);
  return { conflicts: rows.map(toConflict) };
}

// POST /conflicts/:id/resolve
async function resolve(viewer, id, resolution) {
  if (!RESOLUTIONS.includes(resolution)) throw new AppError(400, 'VALIDATION_ERROR', 'Unknown resolution');
  return db.withTransaction(async (client) => {
    const params = [id];
    const filter = await scopeFilter(client, viewer, params);
    const { rows: [conflict] } = await client.query(
      `SELECT c.* FROM sync_conflicts c WHERE c.id = $1${filter} FOR UPDATE OF c`,
      params,
    );
    if (!conflict) throw new AppError(404, 'NOT_FOUND', 'No conflict with this ID in your areas');
    if (conflict.status !== 'pending') throw new AppError(409, 'ALREADY_RESOLVED', 'This conflict has already been resolved');

    const incoming = conflict.incoming_payload;
    const onBehalf = { areaId: conflict.area_id, userId: conflict.submitted_by, deviceId: conflict.device_id };
    const table = conflict.table_name; // from TABLES when the conflict was made
    const { rowCount: alreadyStored } = await client.query(`SELECT 1 FROM ${table} WHERE id = $1`, [incoming.id]);
    if (!alreadyStored) {
      await insertRecord(client, { ...incoming, deleted: resolution === 'keep_existing' }, {
        ...onBehalf, details: { conflictId: id, resolution, resolvedBy: viewer.id },
      });
    }
    if (resolution === 'keep_incoming' && conflict.existing_record_id) {
      const { rows: [deleted] } = await client.query(
        `UPDATE ${table} SET deleted_at = now() WHERE id = $1 AND deleted_at IS NULL RETURNING server_seq`,
        [conflict.existing_record_id],
      );
      if (deleted) {
        await writeAudit(client, {
          userId: viewer.id, action: 'delete', entityType: table, entityId: conflict.existing_record_id,
          details: { serverSeq: Number(deleted.server_seq), conflictId: id, resolution },
        });
      }
    }
    await client.query(
      `UPDATE sync_conflicts SET status = 'resolved', resolution = $2, resolved_by = $3, resolved_at = now() WHERE id = $1`,
      [id, resolution, viewer.id],
    );
    await writeAudit(client, {
      userId: viewer.id, action: 'sync_conflict', entityType: 'sync_conflicts', entityId: id,
      details: { resolution, incomingRecordId: incoming.id, existingRecordId: conflict.existing_record_id },
    });

    const { rows: [row] } = await client.query(`${LIST_SQL} AND c.id = $1`, [id]);
    return { conflict: toConflict(row) };
  });
}

module.exports = { list, resolve, RESOLUTIONS };
