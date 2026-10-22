const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { writeAudit } = require('./audit.service');
const { supervisorAreaIds } = require('./scope.service');
const { insertRecord } = require('./sync.service');
const { TABLES, normalise } = require('../sync/tables');

// M3 FE-2, M10 FE-3: the supervisor's Conflict Review page. A supervisor of the
// record's area, or an admin, decides; nothing is overwritten without that
// decision, every step writes an audit row (LI-7), and the result reaches the
// phone by pull.
//
// outdated_edit: an edit sent from a phone with an older base version than the
// server's. It was not applied.
//   keep_server   the server's version stays; the record is sent to the phone
//                 again so its held edit is replaced;
//   use_device    the phone's edit is applied as a new version.
//
// possible_duplicate: a woman stored with the same name, husband's name and
// household as one already on the server. Both are stored.
//   different_people  both stay;
//   same_person       the newer record is merged into the earlier one: her
//                     visits move to the earlier woman's active pregnancy (or
//                     her pregnancy moves to the earlier woman), and the newer
//                     records are deleted (soft).
//
// same_parent_same_day: a visit held by the earlier rule (before 22 Oct 2026).
//   keep_both, keep_existing, keep_incoming as before.

const RESOLUTIONS_BY_REASON = {
  outdated_edit: ['keep_server', 'use_device'],
  possible_duplicate: ['different_people', 'same_person'],
  same_parent_same_day: ['keep_both', 'keep_existing', 'keep_incoming'],
};
const RESOLUTIONS = [...new Set(Object.values(RESOLUTIONS_BY_REASON).flat())];

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

// The woman a conflict is about: the visit's, the record itself, or the
// pregnancy's or history's woman.
const LIST_SQL = `
  SELECT c.*, a.name AS area_name,
         su.full_name AS submitted_by_name, sp.lhw_code AS submitted_by_code,
         ru.full_name AS resolved_by_name,
         coalesce(vw.name, ew.name, pw.name) AS woman_name,
         coalesce(vw.patient_code, ew.patient_code, pw.patient_code) AS patient_code,
         coalesce(to_jsonb(ev.*), to_jsonb(ew.*), to_jsonb(eh.*), to_jsonb(ep.*), to_jsonb(eo.*)) AS existing_row,
         to_jsonb(iw.*) AS incoming_row
  FROM sync_conflicts c
  JOIN areas a ON a.id = c.area_id
  LEFT JOIN users su ON su.id = c.submitted_by
  LEFT JOIN lhw_profiles sp ON sp.user_id = c.submitted_by
  LEFT JOIN users ru ON ru.id = c.resolved_by
  LEFT JOIN visits ev ON c.table_name = 'visits' AND ev.id = c.existing_record_id
  LEFT JOIN pregnancies vp ON vp.id = ev.pregnancy_id
  LEFT JOIN women vw ON vw.id = vp.woman_id
  LEFT JOIN women ew ON c.table_name = 'women' AND ew.id = c.existing_record_id
  LEFT JOIN women iw ON c.table_name = 'women' AND c.reason = 'possible_duplicate' AND iw.id = c.incoming_record_id
  LEFT JOIN households eh ON c.table_name = 'households' AND eh.id = c.existing_record_id
  LEFT JOIN pregnancies ep ON c.table_name = 'pregnancies' AND ep.id = c.existing_record_id
  LEFT JOIN obstetric_history eo ON c.table_name = 'obstetric_history' AND eo.id = c.existing_record_id
  LEFT JOIN women pw ON pw.id = coalesce(ep.woman_id, eo.woman_id)
  WHERE true`;

function toConflict(row) {
  const incoming = row.incoming_payload;
  const existing = row.existing_row;
  return {
    id: row.id,
    table: row.table_name,
    reason: row.reason,
    resolutions: RESOLUTIONS_BY_REASON[row.reason],
    status: row.status,
    resolution: row.resolution,
    createdAt: row.created_at,
    resolvedAt: row.resolved_at,
    resolvedBy: row.resolved_by_name,
    areaId: row.area_id,
    areaName: row.area_name,
    baseVersion: row.base_version,
    existingVersion: row.existing_version,
    submittedBy: { lhwCode: row.submitted_by_code, fullName: row.submitted_by_name },
    woman: row.patient_code ? { name: row.woman_name, patientCode: row.patient_code } : null,
    incoming: {
      id: incoming.id,
      data: incoming.data,
      deleted: row.incoming_row ? row.incoming_row.deleted_at !== null : Boolean(incoming.deleted),
    },
    existing: existing
      ? { id: existing.id, version: existing.version, deleted: existing.deleted_at !== null, data: recordData(row.table_name, existing) }
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

// Soft-deletes one row and audits it.
async function softDelete(client, viewer, table, id, details) {
  const { rows: [row] } = await client.query(
    `UPDATE ${table} SET deleted_at = now() WHERE id = $1 AND deleted_at IS NULL RETURNING server_seq`,
    [id],
  );
  if (row) {
    await writeAudit(client, {
      userId: viewer.id, action: 'delete', entityType: table, entityId: id, details: { serverSeq: Number(row.server_seq), ...details },
    });
  }
}

// Moves rows to another parent and audits each edit.
async function moveRows(client, viewer, table, column, fromId, toId, details) {
  // table and column are fixed below, never from input.
  const { rows } = await client.query(
    `UPDATE ${table} SET ${column} = $2 WHERE ${column} = $1 AND deleted_at IS NULL RETURNING id, server_seq`,
    [fromId, toId],
  );
  for (const row of rows) {
    await writeAudit(client, {
      userId: viewer.id, action: 'edit', entityType: table, entityId: row.id,
      details: { serverSeq: Number(row.server_seq), [column]: toId, ...details },
    });
  }
}

// same_person: the newer woman (incoming) is merged into the earlier one (existing).
async function mergeWomen(client, viewer, incomingId, existingId, details) {
  const { rows: [active] } = await client.query(
    `SELECT id FROM pregnancies WHERE woman_id = $1 AND status = 'active' AND deleted_at IS NULL`,
    [existingId],
  );
  const { rows: pregnancies } = await client.query(
    'SELECT id, status FROM pregnancies WHERE woman_id = $1 AND deleted_at IS NULL',
    [incomingId],
  );
  for (const pregnancy of pregnancies) {
    if (active && pregnancy.status === 'active') {
      await moveRows(client, viewer, 'visits', 'pregnancy_id', pregnancy.id, active.id, details);
      await softDelete(client, viewer, 'pregnancies', pregnancy.id, details);
    } else {
      await client.query('UPDATE pregnancies SET woman_id = $2 WHERE id = $1', [pregnancy.id, existingId]);
      await writeAudit(client, {
        userId: viewer.id, action: 'edit', entityType: 'pregnancies', entityId: pregnancy.id, details: { womanId: existingId, ...details },
      });
    }
  }
  const { rowCount: hasHistory } = await client.query(
    'SELECT 1 FROM obstetric_history WHERE woman_id = $1 AND deleted_at IS NULL',
    [existingId],
  );
  if (hasHistory) {
    const { rows: histories } = await client.query(
      'SELECT id FROM obstetric_history WHERE woman_id = $1 AND deleted_at IS NULL',
      [incomingId],
    );
    for (const history of histories) await softDelete(client, viewer, 'obstetric_history', history.id, details);
  } else {
    await moveRows(client, viewer, 'obstetric_history', 'woman_id', incomingId, existingId, details);
  }
  await softDelete(client, viewer, 'women', incomingId, details);
}

// Applies a phone's held edit as a new version.
async function applyEdit(client, viewer, table, record, details) {
  const def = TABLES[table];
  const names = Object.keys(def.fields);
  const assignments = names.map((name, i) => `${def.fields[name].column} = $${i + 3}`).join(', ');
  const { rows: [updated] } = await client.query(
    `UPDATE ${table} SET ${assignments}, deleted_at = CASE WHEN $2::boolean THEN coalesce(deleted_at, now()) END
     WHERE id = $1 RETURNING server_seq, version`,
    [record.id, Boolean(record.deleted), ...names.map((name) => record.data[name])],
  );
  await writeAudit(client, {
    userId: viewer.id, action: 'edit', entityType: table, entityId: record.id,
    details: { serverSeq: Number(updated.server_seq), version: updated.version, ...details },
  });
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
    if (!RESOLUTIONS_BY_REASON[conflict.reason].includes(resolution)) {
      throw new AppError(400, 'VALIDATION_ERROR', `This conflict is decided with ${RESOLUTIONS_BY_REASON[conflict.reason].join(' or ')}`);
    }

    const incoming = conflict.incoming_payload;
    const table = conflict.table_name; // from TABLES when the conflict was made
    const details = { conflictId: id, resolution };

    if (conflict.reason === 'outdated_edit') {
      if (resolution === 'use_device') {
        await applyEdit(client, viewer, table, incoming, details);
      } else {
        // The row gets a new number, so the phone pulls the server's version and drops its held edit.
        await client.query(`UPDATE ${table} SET version = version WHERE id = $1`, [incoming.id]);
      }
    } else if (conflict.reason === 'possible_duplicate') {
      if (resolution === 'same_person') {
        await mergeWomen(client, viewer, incoming.id, conflict.existing_record_id, details);
      }
    } else {
      const onBehalf = { areaId: conflict.area_id, userId: conflict.submitted_by, deviceId: conflict.device_id };
      const { rowCount: alreadyStored } = await client.query(`SELECT 1 FROM ${table} WHERE id = $1`, [incoming.id]);
      if (!alreadyStored) {
        await insertRecord(client, { ...incoming, deleted: resolution === 'keep_existing' }, {
          ...onBehalf, details: { ...details, resolvedBy: viewer.id },
        });
      }
      if (resolution === 'keep_incoming' && conflict.existing_record_id) {
        await softDelete(client, viewer, table, conflict.existing_record_id, details);
      }
    }

    await client.query(
      `UPDATE sync_conflicts SET status = 'resolved', resolution = $2, resolved_by = $3, resolved_at = now() WHERE id = $1`,
      [id, resolution, viewer.id],
    );
    await writeAudit(client, {
      userId: viewer.id, action: 'sync_conflict', entityType: 'sync_conflicts', entityId: id,
      details: { resolution, reason: conflict.reason, incomingRecordId: incoming.id, existingRecordId: conflict.existing_record_id },
    });

    const { rows: [row] } = await client.query(`${LIST_SQL} AND c.id = $1`, [id]);
    return { conflict: toConflict(row) };
  });
}

module.exports = { list, resolve, RESOLUTIONS, RESOLUTIONS_BY_REASON };
