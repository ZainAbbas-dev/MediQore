const db = require('../db/pool');
const { writeAudit } = require('./audit.service');
const AppError = require('../utils/app-error');

const WORKER_SCOPE = `
  u.role = 'lhw' AND u.deleted_at IS NULL AND p.deleted_at IS NULL AND a.deleted_at IS NULL
  AND ($1::uuid IS NULL OR EXISTS (
    SELECT 1 FROM supervisor_areas s
    WHERE s.supervisor_id = $1 AND s.area_id = p.area_id AND s.deleted_at IS NULL
  ))`;

const scopeFor = (viewer) => (viewer.role === 'admin' ? null : viewer.id);

function positiveThreshold(value, fallback, integer = false) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 && (!integer || Number.isSafeInteger(parsed)) ? parsed : fallback;
}

function thresholds() {
  return {
    minHistoryWeeks: positiveThreshold(process.env.INACTIVITY_MIN_HISTORY_WEEKS, 6, true),
    minVisitDrop: positiveThreshold(process.env.INACTIVITY_MIN_VISIT_DROP, 3, true),
    standardDeviations: positiveThreshold(process.env.INACTIVITY_STANDARD_DEVIATIONS, 2),
  };
}

function assess(row, { minHistoryWeeks, minVisitDrop, standardDeviations }) {
  const historyWeeks = row.is_synced ? row.history_weeks : null;
  const visits = row.is_synced ? row.visits : null;
  const exclusion = row.exclusion;
  let status;
  if (exclusion) status = 'excluded';
  else if (!row.is_synced) status = 'not_synced';
  else if (historyWeeks < minHistoryWeeks) status = 'insufficient_history';
  else {
    const visitSum = Number(row.visit_sum);
    // Compare with population standard deviation. Scaling by the week count
    // before squaring preserves the strict threshold at exact boundaries.
    const scaledDrop = visitSum - visits * historyWeeks;
    const scaledVariance = Number(row.visit_square_sum) * historyWeeks - visitSum ** 2;
    const unusual = scaledDrop >= minVisitDrop * historyWeeks
      && scaledDrop ** 2 > standardDeviations ** 2 * scaledVariance;
    status = unusual ? 'unusual_inactivity' : 'active';
  }
  return { status, visits, historyWeeks, exclusion };
}

// Evaluate the latest closed Pakistan week using calendar weeks before it.
// After a sync covers the week, earlier weeks are covered too. History starts
// with the first activation or first recorded visit, whichever is earlier.
// Calendar weeks without visits still count toward history.
async function getInactivity(viewer, lhwIds = null, { now = new Date() } = {}) {
  const { rows } = await db.query(
    `WITH calendar AS (
       SELECT date_trunc('week', $3::timestamptz AT TIME ZONE 'Asia/Karachi')::date AS week_end
     ), workers AS (
       SELECT u.id, u.full_name, p.lhw_code, a.name AS area,
              d.first_activation, d.last_sync_at
       FROM users u
       JOIN lhw_profiles p ON p.user_id = u.id
       JOIN areas a ON a.id = p.area_id
       LEFT JOIN LATERAL (
         SELECT min(activated_at) AS first_activation, max(last_records_sync_at) AS last_sync_at
         FROM devices WHERE user_id = u.id
       ) d ON true
       WHERE ${WORKER_SCOPE} AND ($2::uuid[] IS NULL OR u.id = ANY($2))
     ), visit_weeks AS (
       SELECT v.created_by AS lhw_id,
              date_trunc('week', v.visited_at AT TIME ZONE 'Asia/Karachi')::date AS week_start,
              count(*)::int AS visits
       FROM visits v
       JOIN workers w ON w.id = v.created_by
       CROSS JOIN calendar c
       WHERE v.deleted_at IS NULL AND v.visited_at < c.week_end::timestamp AT TIME ZONE 'Asia/Karachi'
         AND ($1::uuid IS NULL OR EXISTS (
           SELECT 1 FROM supervisor_areas s
           WHERE s.supervisor_id = $1 AND s.area_id = v.area_id AND s.deleted_at IS NULL
         ))
       GROUP BY v.created_by, 2
     ), visit_starts AS (
       SELECT lhw_id, min(week_start) AS first_visit_week FROM visit_weeks GROUP BY lhw_id
     ), windows AS (
       SELECT w.id, c.week_end - 7 AS week_start,
              least(s.first_visit_week, date_trunc('week', w.first_activation AT TIME ZONE 'Asia/Karachi')::date) AS history_start,
              coalesce(w.last_sync_at >= c.week_end::timestamp AT TIME ZONE 'Asia/Karachi', false) AS is_synced
       FROM workers w
       CROSS JOIN calendar c
       LEFT JOIN visit_starts s ON s.lhw_id = w.id
     ), excluded_weeks AS (
       SELECT e.lhw_user_id, e.week_start, e.kind
       FROM leave_and_campaign_weeks e
       JOIN windows n ON n.id = e.lhw_user_id
       WHERE e.deleted_at IS NULL AND e.week_start BETWEEN coalesce(n.history_start, n.week_start) AND n.week_start
     ), excluded_history AS (
       SELECT e.lhw_user_id, count(*)::int AS count
       FROM excluded_weeks e JOIN windows n ON n.id = e.lhw_user_id
       WHERE e.week_start < n.week_start
       GROUP BY e.lhw_user_id
     ), visit_history AS (
       SELECT v.lhw_id, sum(v.visits) AS visit_sum, sum(v.visits::numeric * v.visits) AS visit_square_sum
       FROM visit_weeks v
       JOIN windows n ON n.id = v.lhw_id
       LEFT JOIN excluded_weeks e ON e.lhw_user_id = v.lhw_id AND e.week_start = v.week_start
       WHERE n.is_synced AND v.week_start < n.week_start AND e.lhw_user_id IS NULL
       GROUP BY v.lhw_id
     )
     SELECT w.*, c.week_end - 7 AS week_start, n.is_synced, e.kind AS exclusion,
            greatest(0, (n.week_start - n.history_start) / 7 - coalesce(x.count, 0)) AS history_weeks,
            coalesce(v.visits, 0) AS visits, coalesce(h.visit_sum, 0) AS visit_sum,
            coalesce(h.visit_square_sum, 0) AS visit_square_sum
     FROM calendar c
     LEFT JOIN workers w ON true
     LEFT JOIN windows n ON n.id = w.id
     LEFT JOIN excluded_weeks e ON e.lhw_user_id = w.id AND e.week_start = n.week_start
     LEFT JOIN excluded_history x ON x.lhw_user_id = w.id
     LEFT JOIN visit_weeks v ON v.lhw_id = w.id AND v.week_start = n.week_start
     LEFT JOIN visit_history h ON h.lhw_id = w.id
     ORDER BY w.area, w.lhw_code`,
    [scopeFor(viewer), lhwIds, now],
  );
  const settings = thresholds();
  return {
    weekStart: rows[0].week_start,
    lhws: rows.filter((row) => row.id).map((row) => ({
      id: row.id,
      fullName: row.full_name,
      lhwCode: row.lhw_code,
      area: row.area,
      lastSyncAt: row.last_sync_at,
      inactivity: assess(row, settings),
    })),
  };
}

async function requireWorker(client, viewer, lhwId, forUpdate = false) {
  // Lock the profile during a change to serialize exclusions and area transfers.
  const { rows: [worker] } = await client.query(
    `SELECT p.area_id FROM users u
     JOIN lhw_profiles p ON p.user_id = u.id
     JOIN areas a ON a.id = p.area_id
     WHERE ${WORKER_SCOPE} AND u.id = $2
     ${forUpdate ? 'FOR UPDATE OF p' : ''}`,
    [scopeFor(viewer), lhwId],
  );
  if (!worker) throw new AppError(404, 'LHW_NOT_FOUND', 'LHW not found in your areas');
  return worker;
}

const EXCLUSION_FIELDS = 'id, week_start, kind, marked_by, created_at';
const mapExclusion = (row) => ({
  id: row.id,
  weekStart: row.week_start,
  kind: row.kind,
  markedBy: row.marked_by,
  createdAt: row.created_at,
});

async function listExclusions(viewer, lhwId) {
  return db.withTransaction(async (client) => {
    await requireWorker(client, viewer, lhwId);
    const { rows } = await client.query(
      `SELECT ${EXCLUSION_FIELDS} FROM leave_and_campaign_weeks
       WHERE lhw_user_id = $1 AND deleted_at IS NULL ORDER BY week_start DESC`,
      [lhwId],
    );
    return { exclusions: rows.map(mapExclusion) };
  }, { readOnly: true });
}

async function setExclusion(viewer, lhwId, weekStart, kind) {
  return db.withTransaction(async (client) => {
    const { area_id: areaId } = await requireWorker(client, viewer, lhwId, true);
    const { rows: [existing] } = await client.query(
      `SELECT ${EXCLUSION_FIELDS} FROM leave_and_campaign_weeks
       WHERE lhw_user_id = $1 AND week_start = $2 AND deleted_at IS NULL`,
      [lhwId, weekStart],
    );

    if (!kind) {
      if (existing) {
        await client.query('UPDATE leave_and_campaign_weeks SET deleted_at = now() WHERE id = $1', [existing.id]);
        await writeAudit(client, {
          userId: viewer.id, action: 'delete', entityType: 'leave_and_campaign_weeks', entityId: existing.id,
          details: { lhwId, areaId, weekStart, previousKind: existing.kind },
        });
      }
      return null;
    }

    if (existing?.kind === kind) return { exclusion: mapExclusion(existing) };
    const { rows: [row] } = existing
      ? await client.query(
        `UPDATE leave_and_campaign_weeks SET kind = $2, marked_by = $3 WHERE id = $1 RETURNING ${EXCLUSION_FIELDS}`,
        [existing.id, kind, viewer.id],
      )
      : await client.query(
        `INSERT INTO leave_and_campaign_weeks (lhw_user_id, week_start, kind, marked_by)
         VALUES ($1, $2, $3, $4) RETURNING ${EXCLUSION_FIELDS}`,
        [lhwId, weekStart, kind, viewer.id],
      );
    await writeAudit(client, {
      userId: viewer.id, action: existing ? 'edit' : 'create', entityType: 'leave_and_campaign_weeks', entityId: row.id,
      details: { lhwId, areaId, weekStart, kind, ...(existing ? { previousKind: existing.kind } : {}) },
    });
    return { exclusion: mapExclusion(row) };
  });
}

module.exports = { getInactivity, listExclusions, setExclusion };
