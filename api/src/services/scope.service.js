const AppError = require('../utils/app-error');

// Area scoping (roadmap, Security and access): an LHW sees only her area, a
// supervisor only the areas assigned to them. `db` is the pool or a transaction client.

async function lhwAreaId(db, userId) {
  const { rows } = await db.query(
    'SELECT area_id FROM lhw_profiles WHERE user_id = $1 AND deleted_at IS NULL',
    [userId],
  );
  if (!rows.length) throw new AppError(403, 'NO_AREA', 'This account has no assigned area');
  return rows[0].area_id;
}

async function supervisorAreaIds(db, userId) {
  const { rows } = await db.query(
    'SELECT area_id FROM supervisor_areas WHERE supervisor_id = $1 AND deleted_at IS NULL',
    [userId],
  );
  return rows.map((row) => row.area_id);
}

module.exports = { lhwAreaId, supervisorAreaIds };
