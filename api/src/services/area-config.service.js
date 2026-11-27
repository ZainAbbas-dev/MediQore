const { randomUUID } = require('node:crypto');
const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { writeAudit } = require('./audit.service');
const { managedAreaIds } = require('./scope.service');

const AREA_COLUMNS = 'a.id AS area_id, a.name AS area_name, uc.name AS union_council, t.name AS tehsil, d.name AS district';
const GEOGRAPHY_JOINS = `
  JOIN union_councils uc ON uc.id = a.union_council_id
  JOIN tehsils t ON t.id = uc.tehsil_id
  JOIN districts d ON d.id = t.district_id`;
const AREA_ORDER = 'd.name, t.name, uc.name, a.name, a.id';

function areaDetails(row) {
  return { id: row.area_id, name: row.area_name, unionCouncil: row.union_council, tehsil: row.tehsil, district: row.district };
}

async function areaOptions(client, areaIds) {
  const { rows } = await client.query(
    `SELECT ${AREA_COLUMNS} FROM areas a ${GEOGRAPHY_JOINS}
     WHERE a.deleted_at IS NULL AND uc.deleted_at IS NULL AND t.deleted_at IS NULL AND d.deleted_at IS NULL
       AND ($1::uuid[] IS NULL OR a.id = ANY($1))
     ORDER BY ${AREA_ORDER}`,
    [areaIds],
  );
  return rows.map(areaDetails);
}

function requireScope(scope, areaIds) {
  if (scope && areaIds.some((id) => !scope.includes(id))) {
    throw new AppError(403, 'OUT_OF_AREA', 'This action includes an area outside your assignments');
  }
}

async function requireAreas(client, areaIds) {
  if ((await areaOptions(client, areaIds)).length !== areaIds.length) {
    throw new AppError(400, 'UNKNOWN_AREA', 'One of the selected areas does not exist');
  }
}

// Serialize edits to the same configuration before reading the current state.
async function lockConfig(client, entityType, id) {
  await client.query('SELECT pg_advisory_xact_lock(hashtext($1), hashtext($2))', [entityType, id]);
}

const CONTACT_FIELDS = {
  supervisorUserId: 'supervisor_user_id',
  supervisorPhone: 'supervisor_phone',
  secondaryName: 'secondary_name',
  secondaryPhone: 'secondary_phone',
  escalateAfterMinutes: 'escalate_after_minutes',
};

function contactDetails(row) {
  return {
    id: row.id,
    area: areaDetails(row),
    ...Object.fromEntries(Object.entries(CONTACT_FIELDS).map(([field, column]) => [field, row[column]])),
  };
}

async function contactRows(client, scope, areaId = null) {
  const { rows } = await client.query(
    `SELECT c.*, ${AREA_COLUMNS} FROM escalation_contacts c
     JOIN areas a ON a.id = c.area_id ${GEOGRAPHY_JOINS}
     WHERE c.deleted_at IS NULL AND ($1::uuid[] IS NULL OR c.area_id = ANY($1))
       AND ($2::uuid IS NULL OR c.area_id = $2)
     ORDER BY ${AREA_ORDER}`,
    [scope, areaId],
  );
  return rows;
}

async function contactOptions(viewer) {
  return db.withTransaction(async (client) => {
    const scope = await managedAreaIds(client, viewer);
    const areas = await areaOptions(client, scope);
    const { rows: supervisors } = await client.query(
      `SELECT u.id AS "userId", s.area_id AS "areaId", u.full_name AS "fullName", u.phone
       FROM supervisor_areas s JOIN users u ON u.id = s.supervisor_id
       WHERE s.deleted_at IS NULL AND u.is_active AND u.role = 'supervisor' AND u.deleted_at IS NULL
         AND s.area_id = ANY($1::uuid[])
       ORDER BY u.full_name, u.id`,
      [areas.map(({ id }) => id)],
    );
    return { areas, supervisors };
  }, { readOnly: true });
}

async function listContacts(viewer) {
  const scope = await managedAreaIds(db, viewer);
  return (await contactRows(db, scope)).map(contactDetails);
}

async function getContact(viewer, areaId) {
  const scope = await managedAreaIds(db, viewer);
  const [row] = await contactRows(db, scope, areaId);
  if (!row) throw new AppError(404, 'NOT_FOUND', 'No escalation contact for this area');
  return contactDetails(row);
}

async function saveContact(viewer, areaId, values) {
  return db.withTransaction(async (client) => {
    await lockConfig(client, 'escalation_contacts', areaId);
    const scope = await managedAreaIds(client, viewer);
    requireScope(scope, [areaId]);
    await requireAreas(client, [areaId]);
    if (Boolean(values.secondaryName) !== Boolean(values.secondaryPhone)) {
      throw new AppError(400, 'VALIDATION_ERROR', 'Enter both the secondary contact name and phone');
    }
    const [previous] = await contactRows(client, scope, areaId);
    if (values.supervisorUserId && values.supervisorUserId !== previous?.supervisor_user_id) {
      const { rowCount } = await client.query(
        `SELECT 1 FROM supervisor_areas s JOIN users u ON u.id = s.supervisor_id
         WHERE s.area_id = $1 AND u.id = $2 AND s.deleted_at IS NULL
           AND u.role = 'supervisor' AND u.is_active AND u.deleted_at IS NULL`,
        [areaId, values.supervisorUserId],
      );
      if (!rowCount) throw new AppError(400, 'INVALID_SUPERVISOR', 'Choose an active supervisor assigned to this area');
    }
    const fields = Object.keys(CONTACT_FIELDS);
    const changed = fields.filter((field) => previous?.[CONTACT_FIELDS[field]] !== values[field]);
    if (!changed.length) return { contact: contactDetails(previous), created: false };

    const { rows: [{ id }] } = await client.query(
      `INSERT INTO escalation_contacts (
         area_id, created_by, supervisor_user_id, supervisor_phone, secondary_name, secondary_phone, escalate_after_minutes
       ) VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (area_id) WHERE deleted_at IS NULL
       DO UPDATE SET supervisor_user_id = EXCLUDED.supervisor_user_id, supervisor_phone = EXCLUDED.supervisor_phone,
                     secondary_name = EXCLUDED.secondary_name, secondary_phone = EXCLUDED.secondary_phone,
                     escalate_after_minutes = EXCLUDED.escalate_after_minutes
       RETURNING id`,
      [areaId, viewer.id, ...fields.map((field) => values[field])],
    );
    await writeAudit(client, {
      userId: viewer.id, action: previous ? 'edit' : 'create', entityType: 'escalation_contacts', entityId: id,
      details: { areaId, fields: changed },
    });
    const [saved] = await contactRows(client, scope, areaId);
    return { contact: contactDetails(saved), created: !previous };
  });
}

async function deleteContact(viewer, areaId) {
  await db.withTransaction(async (client) => {
    await lockConfig(client, 'escalation_contacts', areaId);
    const [row] = await contactRows(client, await managedAreaIds(client, viewer), areaId);
    if (!row) throw new AppError(404, 'NOT_FOUND', 'No escalation contact for this area');
    await client.query('UPDATE escalation_contacts SET deleted_at = now() WHERE id = $1', [row.id]);
    await writeAudit(client, {
      userId: viewer.id, action: 'delete', entityType: 'escalation_contacts', entityId: row.id, details: { areaId },
    });
  });
}

async function campaignOptions(viewer) {
  return areaOptions(db, await managedAreaIds(db, viewer));
}

async function roundRows(client, scope, roundId = null) {
  const { rows } = await client.query(
    `SELECT c.round_id, c.name, c.starts_on, c.ends_on, ${AREA_COLUMNS},
            ($1::uuid[] IS NULL OR NOT EXISTS (
              SELECT 1 FROM campaigns other WHERE other.round_id = c.round_id AND other.deleted_at IS NULL
                AND other.area_id <> ALL($1::uuid[])
            )) AS editable
     FROM campaigns c JOIN areas a ON a.id = c.area_id ${GEOGRAPHY_JOINS}
     WHERE c.deleted_at IS NULL AND ($1::uuid[] IS NULL OR c.area_id = ANY($1))
       AND ($2::uuid IS NULL OR c.round_id = $2)
     ORDER BY c.starts_on DESC, c.name, c.round_id, ${AREA_ORDER}`,
    [scope, roundId],
  );
  return rows;
}

function groupRounds(rows) {
  const rounds = new Map();
  for (const row of rows) {
    if (!rounds.has(row.round_id)) {
      rounds.set(row.round_id, {
        id: row.round_id, name: row.name, startsOn: row.starts_on, endsOn: row.ends_on, areas: [], editable: row.editable,
      });
    }
    rounds.get(row.round_id).areas.push(areaDetails(row));
  }
  return [...rounds.values()];
}

async function listRounds(viewer) {
  return groupRounds(await roundRows(db, await managedAreaIds(db, viewer)));
}

async function editableRound(client, scope, roundId) {
  const [round] = groupRounds(await roundRows(client, scope, roundId));
  if (!round) throw new AppError(404, 'NOT_FOUND', 'No campaign round with this ID');
  if (!round.editable) throw new AppError(403, 'OUT_OF_AREA', 'This round includes an area outside your assignments');
  return round;
}

function validateRange(startsOn, endsOn) {
  if (endsOn < startsOn) throw new AppError(400, 'VALIDATION_ERROR', 'The end date must be on or after the start date');
}

async function requireRecordedVisitsRetained(client, roundId, removedAreas, { startsOn, endsOn } = {}) {
  const { rowCount } = await client.query(
    `SELECT 1 FROM campaigns c
     JOIN campaign_household_status v ON v.campaign_id = c.id AND v.area_id = c.area_id AND v.deleted_at IS NULL
     WHERE c.round_id = $1 AND c.deleted_at IS NULL
       AND (c.area_id = ANY($2::uuid[])
         OR (v.visited_on BETWEEN c.starts_on AND c.ends_on AND v.visited_on NOT BETWEEN $3::date AND $4::date))
     LIMIT 1`,
    [roundId, removedAreas, startsOn ?? null, endsOn ?? null],
  );
  if (rowCount) {
    throw new AppError(409, 'ROUND_HAS_VISITS', 'Keep the areas and dates of recorded field visits');
  }
}

async function writeRoundAreas(client, viewer, roundId, { name, startsOn, endsOn, areaIds }) {
  await client.query(
    `INSERT INTO campaigns (round_id, created_by, name, starts_on, ends_on, area_id)
     SELECT $1, $2, $3, $4, $5, target.area_id FROM unnest($6::uuid[]) AS target(area_id)
     ON CONFLICT (round_id, area_id) DO UPDATE
     SET name = EXCLUDED.name, starts_on = EXCLUDED.starts_on, ends_on = EXCLUDED.ends_on, deleted_at = NULL
     WHERE (campaigns.name, campaigns.starts_on, campaigns.ends_on, campaigns.deleted_at)
       IS DISTINCT FROM (EXCLUDED.name, EXCLUDED.starts_on, EXCLUDED.ends_on, NULL::timestamptz)`,
    [roundId, viewer.id, name, startsOn, endsOn, areaIds],
  );
}

async function createRound(viewer, values) {
  return db.withTransaction(async (client) => {
    const scope = await managedAreaIds(client, viewer);
    requireScope(scope, values.areaIds);
    await requireAreas(client, values.areaIds);
    validateRange(values.startsOn, values.endsOn);
    const roundId = randomUUID();
    await writeRoundAreas(client, viewer, roundId, values);
    await writeAudit(client, {
      userId: viewer.id, action: 'create', entityType: 'campaigns', entityId: roundId, details: values,
    });
    return editableRound(client, scope, roundId);
  });
}

async function updateRound(viewer, roundId, values) {
  return db.withTransaction(async (client) => {
    await lockConfig(client, 'campaigns', roundId);
    const scope = await managedAreaIds(client, viewer);
    const existing = await editableRound(client, scope, roundId);
    const previousAreas = existing.areas.map(({ id }) => id);
    const schedule = { name: existing.name, startsOn: existing.startsOn, endsOn: existing.endsOn };
    const next = { ...schedule, areaIds: previousAreas, ...values };
    validateRange(next.startsOn, next.endsOn);
    requireScope(scope, next.areaIds);
    if (values.areaIds) await requireAreas(client, next.areaIds);
    const removed = previousAreas.filter((areaId) => !next.areaIds.includes(areaId));
    const added = next.areaIds.filter((areaId) => !previousAreas.includes(areaId));
    const fields = Object.keys(schedule).filter((field) => next[field] !== schedule[field]);
    if (!fields.length && !removed.length && !added.length) return existing;

    if (removed.length || next.startsOn !== schedule.startsOn || next.endsOn !== schedule.endsOn) {
      await requireRecordedVisitsRetained(client, roundId, removed, next);
    }
    if (removed.length) {
      await client.query(
        'UPDATE campaigns SET deleted_at = now() WHERE round_id = $1 AND area_id = ANY($2) AND deleted_at IS NULL',
        [roundId, removed],
      );
    }
    await writeRoundAreas(client, viewer, roundId, next);
    await writeAudit(client, {
      userId: viewer.id, action: 'edit', entityType: 'campaigns', entityId: roundId,
      details: { fields, addedAreaIds: added, removedAreaIds: removed },
    });
    return editableRound(client, scope, roundId);
  });
}

async function deleteRound(viewer, roundId) {
  await db.withTransaction(async (client) => {
    await lockConfig(client, 'campaigns', roundId);
    const round = await editableRound(client, await managedAreaIds(client, viewer), roundId);
    const areaIds = round.areas.map(({ id }) => id);
    await requireRecordedVisitsRetained(client, roundId, areaIds);
    await client.query('UPDATE campaigns SET deleted_at = now() WHERE round_id = $1 AND deleted_at IS NULL', [roundId]);
    await writeAudit(client, {
      userId: viewer.id, action: 'delete', entityType: 'campaigns', entityId: roundId,
      details: { name: round.name, areaIds },
    });
  });
}

module.exports = {
  contactOptions, listContacts, getContact, saveContact, deleteContact,
  campaignOptions, listRounds, createRound, updateRound, deleteRound,
};
