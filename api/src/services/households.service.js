const db = require('../db/pool');
const { supervisorAreaIds } = require('./scope.service');

// Households visible to a portal user: a supervisor sees only their assigned
// areas, an admin sees all. Used by the portal map (M10 FE-1) and the Phase 0
// end-to-end check.
async function listForPortal(user, limit) {
  const params = [limit];
  let areaFilter = '';
  if (user.role === 'supervisor') {
    params.push(await supervisorAreaIds(db, user.id));
    areaFilter = 'AND h.area_id = ANY($2)';
  }

  const { rows } = await db.query(
    `SELECT h.id, h.household_number, h.village, h.address, h.latitude, h.longitude,
            h.area_id, a.name AS area_name, h.server_seq, h.synced_at, h.created_on_device
     FROM households h
     JOIN areas a ON a.id = h.area_id
     WHERE h.deleted_at IS NULL ${areaFilter}
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
    serverSeq: Number(row.server_seq),
    syncedAt: row.synced_at,
    createdOnDevice: row.created_on_device,
  }));
}

module.exports = { listForPortal };
