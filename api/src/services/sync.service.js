const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { writeAudit } = require('./audit.service');
const { lhwAreaId, lhwAreas } = require('./scope.service');
const { TABLES, normalise } = require('../sync/tables');

// M3 FE-2: offline sync skeleton (P0-6), following the roadmap's Offline sync
// track. The server never trusts device clocks: order comes only from server_seq,
// which the database assigns in commit order (see db/migrations).

// Only a phone approved with a one-time code (M1 FE-2) may sync, and only the
// phone the access token was issued to. Push also records when it was last seen.
async function requireApprovedDevice(client, deviceId, user, { touch = false } = {}) {
  if (!user.deviceId || user.deviceId !== deviceId) {
    throw new AppError(403, 'DEVICE_NOT_ALLOWED', 'This request did not come from the phone that signed in');
  }
  const { rows } = await client.query(
    touch
      ? `UPDATE devices SET last_seen_at = now()
         WHERE id = $1 AND user_id = $2 AND verified_at IS NOT NULL AND revoked_at IS NULL RETURNING id`
      : `SELECT id FROM devices
         WHERE id = $1 AND user_id = $2 AND verified_at IS NOT NULL AND revoked_at IS NULL`,
    [deviceId, user.id],
  );
  if (!rows.length) throw new AppError(403, 'DEVICE_NOT_ALLOWED', 'This phone is not approved for this account');
}

function sameAsStored(def, row, record) {
  if ((row.deleted_at !== null) !== record.deleted) return false;
  return Object.entries(def.fields).every(
    ([name, field]) => normalise(field, row[field.column]) === normalise(field, record.data[name]),
  );
}

// The area a new record is filed under: the one the phone made it in, as long
// as the LHW works there now or did before her last reassignment (M1 FE-3).
// Records from an app that does not send the area go to her current area.
function areaForNewRecord(ctx, record) {
  const areaId = record.areaId || ctx.areaId;
  return ctx.allowedAreaIds.includes(areaId) ? areaId : null;
}

// A record that belongs to another (its household, its woman) is accepted only
// when that parent is on the server, not deleted, and in the record's area.
// Returns the reason to refuse the record, or null. A deletion needs no parent.
async function parentProblem(client, def, record, areaId) {
  if (!def.parent || record.deleted) return null;
  // def.parent.table comes from TABLES, never from input.
  const { rows: [parent] } = await client.query(
    `SELECT area_id FROM ${def.parent.table} WHERE id = $1 AND deleted_at IS NULL`,
    [record.data[def.parent.field]],
  );
  if (!parent) return 'MISSING_PARENT';
  return parent.area_id === areaId ? null : 'OUT_OF_AREA';
}

// Database constraints that a pushed record can break, and the reason the
// device is given. The record is refused; the rest of the batch still applies.
const CONSTRAINT_REASONS = {
  women_patient_code_key: 'DUPLICATE_PATIENT_ID',
  pregnancies_one_active_per_woman: 'ACTIVE_PREGNANCY_EXISTS',
  obstetric_history_one_per_woman: 'DUPLICATE_RECORD',
};
const SQLSTATE_REASONS = { 23505: 'DUPLICATE_RECORD', 23503: 'MISSING_PARENT', 23514: 'INVALID_VALUE' };

// Applies one pushed record and returns its result for the device.
async function applyRecord(client, ctx, record) {
  const def = TABLES[record.table];
  const names = Object.keys(def.fields);
  const columns = names.map((name) => def.fields[name].column);
  const values = names.map((name) => record.data[name]);
  const result = { table: record.table, id: record.id };

  // record.table was validated against TABLES, so it is safe to place in SQL.
  const { rows: [existing] } = await client.query(
    `SELECT * FROM ${record.table} WHERE id = $1 FOR UPDATE`,
    [record.id],
  );

  if (!existing) {
    const areaId = areaForNewRecord(ctx, record);
    if (!areaId) return { ...result, status: 'rejected', reason: 'OUT_OF_AREA' };
    const problem = await parentProblem(client, def, record, areaId);
    if (problem) return { ...result, status: 'rejected', reason: problem };
    const placeholders = columns.map((_, i) => `$${i + 6}`).join(', ');
    const { rows: [inserted] } = await client.query(
      `INSERT INTO ${record.table} (id, area_id, created_by, created_on_device, deleted_at, ${columns.join(', ')})
       VALUES ($1, $2, $3, $4, CASE WHEN $5::boolean THEN now() END, ${placeholders})
       RETURNING server_seq`,
      [record.id, areaId, ctx.userId, record.createdOnDevice, record.deleted, ...values],
    );
    const serverSeq = Number(inserted.server_seq);
    await writeAudit(client, {
      userId: ctx.userId, deviceId: ctx.deviceId, action: 'create',
      entityType: record.table, entityId: record.id,
      details: { serverSeq, ...(areaId !== ctx.areaId && { areaId, previousArea: true }) },
    });
    return { ...result, status: 'created', serverSeq };
  }

  if (!ctx.allowedAreaIds.includes(existing.area_id)) {
    return { ...result, status: 'rejected', reason: 'OUT_OF_AREA' };
  }

  // Resending the same record is harmless (roadmap, Offline sync).
  if (sameAsStored(def, existing, record)) {
    return { ...result, status: 'unchanged', serverSeq: Number(existing.server_seq) };
  }

  const problem = await parentProblem(client, def, record, existing.area_id);
  if (problem) return { ...result, status: 'rejected', reason: problem };

  const assignments = columns.map((column, i) => `${column} = $${i + 3}`).join(', ');
  const { rows: [updated] } = await client.query(
    `UPDATE ${record.table}
     SET ${assignments}, deleted_at = CASE WHEN $2::boolean THEN coalesce(deleted_at, now()) END
     WHERE id = $1
     RETURNING server_seq`,
    [record.id, record.deleted, ...values],
  );
  const serverSeq = Number(updated.server_seq);
  await writeAudit(client, {
    userId: ctx.userId, deviceId: ctx.deviceId,
    action: record.deleted && existing.deleted_at === null ? 'delete' : 'edit',
    entityType: record.table, entityId: record.id, details: { serverSeq },
  });
  return { ...result, status: 'updated', serverSeq };
}

// Runs applyRecord inside a savepoint, so a record that breaks a database
// constraint (for example a patient ID already used) is refused on its own
// instead of failing the whole batch.
async function applyRecordOrRefuse(client, ctx, record) {
  await client.query('SAVEPOINT pushed_record');
  try {
    const result = await applyRecord(client, ctx, record);
    await client.query('RELEASE SAVEPOINT pushed_record');
    return result;
  } catch (error) {
    const reason = CONSTRAINT_REASONS[error.constraint] || SQLSTATE_REASONS[error.code];
    if (!reason) throw error;
    await client.query('ROLLBACK TO SAVEPOINT pushed_record');
    return { table: record.table, id: record.id, status: 'rejected', reason };
  }
}

// POST /sync/push: one transaction for the whole batch.
async function push(user, deviceId, records) {
  return db.withTransaction(async (client) => {
    const { areaId, previousAreaId } = await lhwAreas(client, user.id);
    await requireApprovedDevice(client, deviceId, user, { touch: true });
    const allowedAreaIds = previousAreaId ? [areaId, previousAreaId] : [areaId];
    const ctx = { userId: user.id, deviceId, areaId, allowedAreaIds };
    const results = [];
    for (const record of records) {
      results.push(await applyRecordOrRefuse(client, ctx, record));
    }
    return { results };
  });
}

function toRecord(table, def, row) {
  const data = Object.fromEntries(
    Object.entries(def.fields).map(([name, field]) => [name, normalise(field, row[field.column])]),
  );
  return {
    table,
    id: row.id,
    areaId: row.area_id,
    serverSeq: Number(row.server_seq),
    createdOnDevice: row.created_on_device,
    syncedAt: row.synced_at,
    deleted: row.deleted_at !== null,
    data,
  };
}

// GET /sync/pull?since=: everything in the LHW's area numbered after `since`,
// read from one consistent snapshot, oldest first.
async function pull(user, since, limit) {
  return db.withTransaction(async (client) => {
    await requireApprovedDevice(client, user.deviceId, user);
    const areaId = await lhwAreaId(client, user.id);
    const rows = [];
    for (const [table, def] of Object.entries(TABLES)) {
      const { rows: tableRows } = await client.query(
        `SELECT * FROM ${table}
         WHERE area_id = $1 AND server_seq > $2
         ORDER BY server_seq
         LIMIT $3`,
        [areaId, since, limit + 1],
      );
      rows.push(...tableRows.map((row) => toRecord(table, def, row)));
    }
    rows.sort((a, b) => a.serverSeq - b.serverSeq);
    const records = rows.slice(0, limit);
    return {
      records,
      nextSince: records.length ? records[records.length - 1].serverSeq : since,
      hasMore: rows.length > limit,
    };
  }, { readOnly: true });
}

module.exports = { push, pull };
