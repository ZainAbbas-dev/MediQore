const db = require('../db/pool');
const { supervisorAreaIds } = require('./scope.service');

// M10 FE-1 (Phase 1 base): the dashboard's counts for the viewer's areas.
// "This week" starts on Monday, Pakistan time. Visit times come from the
// phone's clock; they are only counted, never used to order records (LI-7).
async function summary(viewer) {
  const params = [];
  let area = 'true';
  if (viewer.role === 'supervisor') {
    params.push(await supervisorAreaIds(db, viewer.id));
    area = 'area_id = ANY($1)';
  }
  const { rows: [row] } = await db.query(
    `SELECT
       (SELECT count(*) FROM women WHERE deleted_at IS NULL AND ${area}) AS registered_women,
       (SELECT count(*) FROM visits WHERE deleted_at IS NULL AND ${area}
          AND visited_at >= (date_trunc('week', now() AT TIME ZONE 'Asia/Karachi') AT TIME ZONE 'Asia/Karachi')) AS visits_this_week,
       (SELECT count(*) FROM sync_conflicts WHERE status = 'pending' AND ${area}) AS pending_conflicts`,
    params,
  );
  return {
    registeredWomen: Number(row.registered_women),
    visitsThisWeek: Number(row.visits_this_week),
    pendingConflicts: Number(row.pending_conflicts),
  };
}

module.exports = { summary };
