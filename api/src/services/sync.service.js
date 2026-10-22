const crypto = require('node:crypto');
const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { writeAudit } = require('./audit.service');
const { lhwAreaId, lhwAreas } = require('./scope.service');
const { TABLES, normalise } = require('../sync/tables');

// M3 FE-2: offline sync skeleton (P0-6), following the roadmap's Offline sync
// track. The server never trusts device clocks: order comes only from server_seq,
// which the database assigns in commit order (see db/migrations).

// Only a phone activated with an activation code (M1 FE-2) may sync, and only
// the phone the access token was issued to. Push and pull both record the sync
// time for the dashboard (M10 FE-1); push also counts as the phone being seen.
async function requireActivatedDevice(client, deviceId, user, { touch = false } = {}) {
  if (!user.deviceId || user.deviceId !== deviceId) {
    throw new AppError(403, 'DEVICE_NOT_ALLOWED', 'This request did not come from the phone that signed in');
  }
  const { rows } = await client.query(
    `UPDATE devices SET last_sync_at = now()${touch ? ', last_seen_at = now()' : ''}
     WHERE id = $1 AND user_id = $2 AND activated_at IS NOT NULL AND revoked_at IS NULL RETURNING id`,
    [deviceId, user.id],
  );
  if (!rows.length) throw new AppError(403, 'DEVICE_NOT_ALLOWED', 'This phone is not activated for this account');
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

// Writes a new record with its audit row and returns its server number. Also
// used when a supervisor accepts a record from the conflict queue.
async function insertRecord(client, record, { areaId, userId, deviceId, details = {} }) {
  const def = TABLES[record.table];
  const names = Object.keys(def.fields);
  const columns = names.map((name) => def.fields[name].column);
  const values = names.map((name) => record.data[name]);
  const placeholders = columns.map((_, i) => `$${i + 6}`).join(', ');
  // record.table was validated against TABLES, so it is safe to place in SQL.
  const { rows: [inserted] } = await client.query(
    `INSERT INTO ${record.table} (id, area_id, created_by, created_on_device, deleted_at, ${columns.join(', ')})
     VALUES ($1, $2, $3, $4, CASE WHEN $5::boolean THEN now() END, ${placeholders})
     RETURNING server_seq`,
    [record.id, areaId, userId, record.createdOnDevice, Boolean(record.deleted), ...values],
  );
  const serverSeq = Number(inserted.server_seq);
  await writeAudit(client, {
    userId, deviceId, action: 'create', entityType: record.table, entityId: record.id, details: { serverSeq, ...details },
  });
  return serverSeq;
}

// Name and husband's name compared without case or extra spaces.
const NORMALISED = (column) => `lower(regexp_replace(trim(coalesce(${column}, '')), '\\s+', ' ', 'g'))`;

// Lists a conflict for the supervisor's Conflict Review page (M3 FE-2, M10 FE-3)
// and audits it. One pending conflict per record and reason: a resend updates
// the payload of the pending one. Returns the conflict ID.
async function listConflict(client, ctx, { table, record, areaId, existingId, reason, baseVersion = null, existingVersion = null }) {
  const { rows: [conflict] } = await client.query(
    `INSERT INTO sync_conflicts
       (area_id, table_name, incoming_record_id, existing_record_id, incoming_payload, reason, submitted_by, device_id,
        base_version, existing_version)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     ON CONFLICT (table_name, incoming_record_id, reason) WHERE status = 'pending'
     DO UPDATE SET incoming_payload = EXCLUDED.incoming_payload, base_version = EXCLUDED.base_version,
                   existing_version = EXCLUDED.existing_version
     RETURNING id, (xmax = 0) AS inserted`,
    [areaId, table, record.id, existingId, JSON.stringify(record), reason, ctx.userId, ctx.deviceId, baseVersion, existingVersion],
  );
  if (conflict.inserted) {
    await writeAudit(client, {
      userId: ctx.userId, deviceId: ctx.deviceId, action: 'sync_conflict', entityType: table, entityId: record.id,
      details: { conflictId: conflict.id, existingRecordId: existingId, reason, baseVersion, existingVersion },
    });
  }
  return conflict.id;
}

// M3 FE-2: a likely duplicate patient (same name, husband's name and household)
// is stored like any record and listed for the supervisor. Returns the
// conflict ID, or null.
async function possibleDuplicate(client, ctx, def, record, areaId) {
  if (!def.duplicateOf || record.deleted) return null;
  const params = [record.id, areaId];
  const same = def.duplicateOf.sameColumns.map((column) => {
    params.push(record.data[Object.keys(def.fields).find((name) => def.fields[name].column === column)]);
    return `${column} = $${params.length}`;
  });
  const similar = def.duplicateOf.sameText.map((column) => {
    params.push(record.data[Object.keys(def.fields).find((name) => def.fields[name].column === column)]);
    return `${NORMALISED(column)} = ${NORMALISED(`$${params.length}::text`)}`;
  });
  // Table and column names come from TABLES, never from input.
  const { rows: [other] } = await client.query(
    `SELECT id FROM ${record.table}
     WHERE id <> $1 AND area_id = $2 AND deleted_at IS NULL AND ${[...same, ...similar].join(' AND ')}
     ORDER BY server_seq LIMIT 1`,
    params,
  );
  if (!other) return null;
  return listConflict(client, ctx, { table: record.table, record, areaId, existingId: other.id, reason: 'possible_duplicate' });
}

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
    const serverSeq = await insertRecord(client, record, {
      areaId, userId: ctx.userId, deviceId: ctx.deviceId,
      details: areaId !== ctx.areaId ? { areaId, previousArea: true } : {},
    });
    const duplicateId = await possibleDuplicate(client, ctx, def, record, areaId);
    return { ...result, status: 'created', serverSeq, version: 1, ...(duplicateId ? { possibleDuplicate: duplicateId } : {}) };
  }

  if (!ctx.allowedAreaIds.includes(existing.area_id)) {
    return { ...result, status: 'rejected', reason: 'OUT_OF_AREA' };
  }

  // Resending the same record is harmless (roadmap, Offline sync).
  // An identical resend is acknowledged again and never a conflict.
  if (sameAsStored(def, existing, record)) {
    return { ...result, status: 'unchanged', serverSeq: Number(existing.server_seq), version: existing.version };
  }

  // M3 FE-2: an edit made on an older version than the server's is not applied.
  // It waits on the Conflict Review page, and the phone keeps it held until the
  // supervisor's decision comes back by pull.
  if (record.baseVersion !== undefined && record.baseVersion < existing.version) {
    const conflictId = await listConflict(client, ctx, {
      table: record.table, record, areaId: existing.area_id, existingId: existing.id, reason: 'outdated_edit',
      baseVersion: record.baseVersion, existingVersion: existing.version,
    });
    return { ...result, status: 'conflict', conflictId };
  }

  const problem = await parentProblem(client, def, record, existing.area_id);
  if (problem) return { ...result, status: 'rejected', reason: problem };

  const assignments = columns.map((column, i) => `${column} = $${i + 3}`).join(', ');
  const { rows: [updated] } = await client.query(
    `UPDATE ${record.table}
     SET ${assignments}, deleted_at = CASE WHEN $2::boolean THEN coalesce(deleted_at, now()) END
     WHERE id = $1
     RETURNING server_seq, version`,
    [record.id, record.deleted, ...values],
  );
  const serverSeq = Number(updated.server_seq);
  await writeAudit(client, {
    userId: ctx.userId, deviceId: ctx.deviceId,
    action: record.deleted && existing.deleted_at === null ? 'delete' : 'edit',
    entityType: record.table, entityId: record.id, details: { serverSeq, version: updated.version },
  });
  return { ...result, status: 'updated', serverSeq, version: updated.version };
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
    await requireActivatedDevice(client, deviceId, user, { touch: true });
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
    version: row.version,
    createdOnDevice: row.created_on_device,
    syncedAt: row.synced_at,
    deleted: row.deleted_at !== null,
    data,
  };
}

// GET /sync/pull?since=: everything in the LHW's area numbered after `since`,
// read from one consistent snapshot, oldest first.
async function pull(user, since, limit) {
  // The device check writes the sync time, so it runs before the read-only snapshot.
  await requireActivatedDevice(db, user.deviceId, user);
  return db.withTransaction(async (client) => {
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

// The Clinical Rules Table in the repository, used when the server has loaded none.
const BUNDLED_RULES = require('../../../clinical-rules/clinical-rules.json');

// GET /sync/config?have=: what the phone needs for its area besides records
// (M3 FE-2): referral facilities of her district, her area's escalation
// contacts and polio campaign rounds, and the Clinical Rules Table in force
// (its EPI configuration included). `configVersion` is a hash of the answer;
// when the phone already has it, only the hash comes back.
async function config(user, have) {
  await requireActivatedDevice(db, user.deviceId, user);
  const areaId = await lhwAreaId(db, user.id);
  const { rows: [place] } = await db.query(
    `SELECT t.district_id FROM areas a
     JOIN union_councils u ON u.id = a.union_council_id
     JOIN tehsils t ON t.id = u.tehsil_id
     WHERE a.id = $1`,
    [areaId],
  );
  const { rows: facilities } = await db.query(
    `SELECT id, 'hospital' AS kind, name, facility_type AS type, phone, address, latitude, longitude
     FROM hospitals WHERE district_id = $1 AND deleted_at IS NULL AND (area_id IS NULL OR area_id = $2)
     UNION ALL
     SELECT id, 'referral_centre' AS kind, name, centre_type AS type, phone, address, latitude, longitude
     FROM referral_centres WHERE district_id = $1 AND deleted_at IS NULL AND (area_id IS NULL OR area_id = $2)
     ORDER BY name, id`,
    [place.district_id, areaId],
  );
  const { rows: contacts } = await db.query(
    `SELECT supervisor_phone, secondary_name, secondary_phone, escalate_after_minutes
     FROM escalation_contacts WHERE area_id = $1 AND deleted_at IS NULL`,
    [areaId],
  );
  const { rows: campaigns } = await db.query(
    `SELECT id, name, starts_on, ends_on FROM campaigns
     WHERE area_id = $1 AND deleted_at IS NULL AND ends_on >= (now() AT TIME ZONE 'Asia/Karachi')::date
     ORDER BY starts_on, id`,
    [areaId],
  );
  const { rows: [loaded] } = await db.query(
    `SELECT content FROM clinical_rules_versions
     WHERE review_status <> 'retired' AND effective_from <= (now() AT TIME ZONE 'Asia/Karachi')::date
     ORDER BY effective_from DESC, created_at DESC LIMIT 1`,
  );
  const clinicalRules = loaded ? loaded.content : BUNDLED_RULES;
  const answer = {
    facilities: facilities.map((f) => ({
      id: f.id, kind: f.kind, name: f.name, type: f.type, phone: f.phone, address: f.address,
      latitude: f.latitude === null ? null : Number(f.latitude), longitude: f.longitude === null ? null : Number(f.longitude),
    })),
    escalationContact: contacts.length
      ? {
        supervisorPhone: contacts[0].supervisor_phone, secondaryName: contacts[0].secondary_name,
        secondaryPhone: contacts[0].secondary_phone, escalateAfterMinutes: contacts[0].escalate_after_minutes,
      }
      : null,
    campaigns: campaigns.map((c) => ({ id: c.id, name: c.name, startsOn: c.starts_on, endsOn: c.ends_on })),
    clinicalRules,
  };
  const configVersion = crypto.createHash('sha256').update(JSON.stringify(answer)).digest('hex');
  return have === configVersion ? { configVersion, unchanged: true } : { configVersion, unchanged: false, ...answer };
}

module.exports = { push, pull, config, insertRecord, toRecord };
