const db = require('../db/pool');
const { supervisorAreaIds } = require('./scope.service');

// Households visible to a portal user: a supervisor sees only their assigned
// areas, an admin sees all. Used by the dashboard map and table (M10 FE-1),
// which filter them by district, Union Council, LHW and time period. The time
// period counts days back from when the server received the household, never
// from the phone's clock (LI-7).
async function listForPortal(user, { limit, districtId, unionCouncilId, lhwId, days }) {
  const params = [limit];
  const where = ['h.deleted_at IS NULL'];
  const add = (value, condition) => {
    params.push(value);
    where.push(condition.replace('?', `$${params.length}`));
  };
  if (user.role === 'supervisor') add(await supervisorAreaIds(db, user.id), 'h.area_id = ANY(?)');
  if (districtId) add(districtId, 't.district_id = ?');
  if (unionCouncilId) add(unionCouncilId, 'a.union_council_id = ?');
  if (lhwId) add(lhwId, 'h.created_by = ?');
  if (days) add(days, "h.synced_at >= now() - make_interval(days => ?)");

  const { rows } = await db.query(
    `SELECT h.id, h.household_number, h.village, h.address, h.latitude, h.longitude,
            h.area_id, a.name AS area_name, uc.name AS union_council_name, lp.lhw_code,
            h.server_seq, h.synced_at, h.created_on_device
     FROM households h
     JOIN areas a ON a.id = h.area_id
     JOIN union_councils uc ON uc.id = a.union_council_id
     JOIN tehsils t ON t.id = uc.tehsil_id
     LEFT JOIN lhw_profiles lp ON lp.user_id = h.created_by
     WHERE ${where.join(' AND ')}
     ORDER BY h.server_seq DESC
     LIMIT $1`,
    params,
  );

  return rows.map((row) => ({
    id: row.id,
    householdNumber: row.household_number,
    village: row.village,
    address: row.address,
    latitude: row.latitude === null ? null : Number(row.latitude),
    longitude: row.longitude === null ? null : Number(row.longitude),
    areaId: row.area_id,
    areaName: row.area_name,
    unionCouncilName: row.union_council_name,
    registeredBy: row.lhw_code,
    serverSeq: Number(row.server_seq),
    syncedAt: row.synced_at,
    createdOnDevice: row.created_on_device,
  }));
}

module.exports = { listForPortal };
