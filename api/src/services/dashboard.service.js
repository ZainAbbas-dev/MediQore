const db = require('../db/pool');
const { supervisorAreaIds } = require('./scope.service');

// Start of this week (Monday) and of today, Pakistan time.
const WEEK_START = "(date_trunc('week', now() AT TIME ZONE 'Asia/Karachi') AT TIME ZONE 'Asia/Karachi')";
const TODAY_START = "(date_trunc('day', now() AT TIME ZONE 'Asia/Karachi') AT TIME ZONE 'Asia/Karachi')";

// An LHW's last sync: the latest push or pull from her phone, or the latest
// record the server received from her, whichever is later (server clock only).
const LAST_SYNC = `greatest(
  (SELECT max(last_sync_at) FROM devices WHERE user_id = u.id),
  (SELECT max(synced_at) FROM households WHERE created_by = u.id),
  (SELECT max(synced_at) FROM women WHERE created_by = u.id),
  (SELECT max(synced_at) FROM visits WHERE created_by = u.id)
)`;

// The dashboard filters as SQL: `areaColumn` must lie in the viewer's areas and
// the chosen district and Union Council; `byColumn` is the LHW who made the
// record. Returns the conditions to AND together; values go into `params`.
function placeConditions(params, { areaIds, districtId, unionCouncilId, lhwId }, areaColumn, byColumn) {
  const conditions = [];
  const add = (value, condition) => {
    params.push(value);
    conditions.push(condition.replace('?', `$${params.length}`));
  };
  if (areaIds) add(areaIds, `${areaColumn} = ANY(?)`);
  if (districtId) {
    add(districtId, `${areaColumn} IN (SELECT a.id FROM areas a JOIN union_councils uc ON uc.id = a.union_council_id
      JOIN tehsils t ON t.id = uc.tehsil_id WHERE t.district_id = ?)`);
  }
  if (unionCouncilId) add(unionCouncilId, `${areaColumn} IN (SELECT id FROM areas WHERE union_council_id = ?)`);
  if (lhwId && byColumn) add(lhwId, `${byColumn} = ?`);
  return conditions;
}

const and = (conditions) => conditions.map((c) => ` AND ${c}`).join('');

// GET /dashboard/summary (M10 FE-1, Phase 1 base): the dashboard cards for the
// viewer's areas, narrowed by district, Union Council and LHW. Visit times come
// from the phone's clock; they are only counted, never used to order records
// (LI-7). "LHWs synced today" counts active LHWs whose last sync was today.
async function summary(viewer, filters = {}) {
  const scope = { ...filters, areaIds: await scopedAreaIds(viewer) };
  const params = [];
  const women = placeConditions(params, scope, 'area_id', 'created_by');
  const visits = placeConditions(params, scope, 'area_id', 'created_by');
  const conflicts = placeConditions(params, scope, 'area_id', 'submitted_by');
  const lhws = placeConditions(params, scope, 'p.area_id', 'u.id');
  const { rows: [row] } = await db.query(
    `SELECT
       (SELECT count(*) FROM women WHERE deleted_at IS NULL${and(women)}) AS registered_women,
       (SELECT count(*) FROM visits WHERE deleted_at IS NULL AND visited_at >= ${WEEK_START}${and(visits)}) AS visits_this_week,
       (SELECT count(*) FROM sync_conflicts WHERE status = 'pending'${and(conflicts)}) AS pending_conflicts,
       (SELECT count(*) FROM users u JOIN lhw_profiles p ON p.user_id = u.id AND p.deleted_at IS NULL
          WHERE u.role = 'lhw' AND u.deleted_at IS NULL AND u.is_active${and(lhws)}) AS lhws,
       (SELECT count(*) FROM users u JOIN lhw_profiles p ON p.user_id = u.id AND p.deleted_at IS NULL
          WHERE u.role = 'lhw' AND u.deleted_at IS NULL AND u.is_active${and(lhws)}
            AND ${LAST_SYNC} >= ${TODAY_START}) AS lhws_synced_today`,
    params,
  );
  return {
    registeredWomen: Number(row.registered_women),
    visitsThisWeek: Number(row.visits_this_week),
    pendingConflicts: Number(row.pending_conflicts),
    lhws: Number(row.lhws),
    lhwsSyncedToday: Number(row.lhws_synced_today),
  };
}

// The areas a viewer may see, with their Union Council and district. Null for
// an admin (every area).
async function scopedAreaIds(viewer) {
  return viewer.role === 'supervisor' ? supervisorAreaIds(db, viewer.id) : null;
}

// GET /dashboard/filters: the districts, Union Councils and LHWs a viewer can
// filter the map and the LHW activity by (M10 FE-1).
async function filters(viewer) {
  const areaIds = await scopedAreaIds(viewer);
  const params = areaIds ? [areaIds] : [];
  const inScope = areaIds ? 'AND a.id = ANY($1)' : '';
  const { rows: places } = await db.query(
    `SELECT DISTINCT d.id AS district_id, d.name AS district_name, uc.id AS uc_id, uc.name AS uc_name
     FROM areas a
     JOIN union_councils uc ON uc.id = a.union_council_id
     JOIN tehsils t ON t.id = uc.tehsil_id
     JOIN districts d ON d.id = t.district_id
     WHERE a.deleted_at IS NULL ${inScope}
     ORDER BY d.name, uc.name`,
    params,
  );
  const { rows: lhws } = await db.query(
    `SELECT u.id, u.full_name, p.lhw_code, a.union_council_id, t.district_id
     FROM users u
     JOIN lhw_profiles p ON p.user_id = u.id AND p.deleted_at IS NULL
     JOIN areas a ON a.id = p.area_id
     JOIN union_councils uc ON uc.id = a.union_council_id
     JOIN tehsils t ON t.id = uc.tehsil_id
     WHERE u.role = 'lhw' AND u.deleted_at IS NULL ${inScope}
     ORDER BY p.lhw_code`,
    params,
  );
  const districts = new Map();
  for (const row of places) districts.set(row.district_id, { id: row.district_id, name: row.district_name });
  return {
    districts: [...districts.values()],
    unionCouncils: places.map((row) => ({ id: row.uc_id, name: row.uc_name, districtId: row.district_id })),
    lhws: lhws.map((row) => ({
      id: row.id, lhwCode: row.lhw_code, fullName: row.full_name, unionCouncilId: row.union_council_id, districtId: row.district_id,
    })),
  };
}

// GET /dashboard/lhw-activity (M10 FE-1: LHW visit counts and last login),
// narrowed by district, Union Council and LHW. Counts are by the LHW who made
// the record. Visit times come from the phone's clock and are only counted
// (LI-7); "last sync" is the server's time (LAST_SYNC).
async function lhwActivity(viewer, filters) {
  const params = [];
  const where = [
    "u.role = 'lhw'",
    'u.deleted_at IS NULL',
    ...placeConditions(params, { ...filters, areaIds: await scopedAreaIds(viewer) }, 'p.area_id', 'u.id'),
  ];
  const { rows } = await db.query(
    `SELECT u.id, u.full_name, u.is_active, u.last_login_at, p.lhw_code,
            a.name AS area_name, uc.name AS union_council_name, d.name AS district_name,
            (SELECT count(*)::int FROM visits v WHERE v.created_by = u.id AND v.deleted_at IS NULL
               AND v.visited_at >= ${WEEK_START}) AS visits_this_week,
            (SELECT count(*)::int FROM visits v WHERE v.created_by = u.id AND v.deleted_at IS NULL) AS visits_total,
            (SELECT count(*)::int FROM women w WHERE w.created_by = u.id AND w.deleted_at IS NULL) AS women_registered,
            (SELECT max(v.visited_at) FROM visits v WHERE v.created_by = u.id AND v.deleted_at IS NULL) AS last_visit_at,
            ${LAST_SYNC} AS last_sync_at
     FROM users u
     JOIN lhw_profiles p ON p.user_id = u.id AND p.deleted_at IS NULL
     JOIN areas a ON a.id = p.area_id
     JOIN union_councils uc ON uc.id = a.union_council_id
     JOIN tehsils t ON t.id = uc.tehsil_id
     JOIN districts d ON d.id = t.district_id
     WHERE ${where.join(' AND ')}
     ORDER BY d.name, uc.name, p.lhw_code`,
    params,
  );
  return {
    lhws: rows.map((row) => ({
      id: row.id,
      lhwCode: row.lhw_code,
      fullName: row.full_name,
      isActive: row.is_active,
      area: row.area_name,
      unionCouncil: row.union_council_name,
      district: row.district_name,
      visitsThisWeek: row.visits_this_week,
      visitsTotal: row.visits_total,
      womenRegistered: row.women_registered,
      lastVisitAt: row.last_visit_at,
      lastSyncAt: row.last_sync_at,
      lastLoginAt: row.last_login_at,
    })),
  };
}

module.exports = { summary, filters, lhwActivity };
