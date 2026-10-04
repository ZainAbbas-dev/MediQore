const db = require('../db/pool');
const { supervisorAreaIds } = require('./scope.service');

// M2 FE-1, FE-2: registered women for the portal (M10 FE-1 shows registered
// patients). A supervisor sees only their assigned areas, an admin sees all.
// Each row carries the woman's household, her latest pregnancy and her
// obstetric history, so the list needs one request.
async function listForPortal(user, { search, limit }) {
  const params = [limit];
  const filters = ['w.deleted_at IS NULL'];
  if (user.role === 'supervisor') {
    params.push(await supervisorAreaIds(db, user.id));
    filters.push(`w.area_id = ANY($${params.length})`);
  }
  if (search) {
    params.push(`%${search.replace(/[\\%_]/g, (c) => `\\${c}`)}%`);
    const p = `$${params.length}`;
    filters.push(`(w.name ILIKE ${p} OR w.patient_code ILIKE ${p} OR w.husband_name ILIKE ${p} OR h.village ILIKE ${p})`);
  }

  const { rows } = await db.query(
    `SELECT w.id, w.patient_code, w.name, w.age, w.husband_name, w.contact_number, w.server_seq, w.synced_at,
            w.area_id, a.name AS area_name,
            h.id AS household_id, h.village, h.address, h.latitude, h.longitude,
            lp.lhw_code AS registered_by_code, u.full_name AS registered_by_name,
            p.registered_on, p.pregnancy_month_at_registration, p.status AS pregnancy_status,
            o.previous_pregnancies, o.previous_c_sections, o.stillbirths, o.known_conditions,
            count(*) OVER () AS total
     FROM women w
     JOIN areas a ON a.id = w.area_id
     JOIN households h ON h.id = w.household_id
     JOIN users u ON u.id = w.created_by
     LEFT JOIN lhw_profiles lp ON lp.user_id = w.created_by
     LEFT JOIN LATERAL (
       SELECT registered_on, pregnancy_month_at_registration, status FROM pregnancies
       WHERE woman_id = w.id AND deleted_at IS NULL
       ORDER BY (status = 'active') DESC, server_seq DESC LIMIT 1
     ) p ON true
     LEFT JOIN obstetric_history o ON o.woman_id = w.id AND o.deleted_at IS NULL
     WHERE ${filters.join(' AND ')}
     ORDER BY w.server_seq DESC
     LIMIT $1`,
    params,
  );

  return {
    total: rows.length ? Number(rows[0].total) : 0,
    women: rows.map((row) => ({
      id: row.id,
      patientCode: row.patient_code,
      name: row.name,
      age: row.age,
      husbandName: row.husband_name,
      contactNumber: row.contact_number,
      areaId: row.area_id,
      areaName: row.area_name,
      household: {
        id: row.household_id,
        village: row.village,
        address: row.address,
        latitude: row.latitude === null ? null : Number(row.latitude),
        longitude: row.longitude === null ? null : Number(row.longitude),
      },
      registeredBy: { lhwCode: row.registered_by_code, fullName: row.registered_by_name },
      pregnancy: row.registered_on === null ? null : {
        registeredOn: row.registered_on,
        monthAtRegistration: row.pregnancy_month_at_registration,
        status: row.pregnancy_status,
      },
      obstetricHistory: row.previous_pregnancies === null ? null : {
        previousPregnancies: row.previous_pregnancies,
        previousCSections: row.previous_c_sections,
        stillbirths: row.stillbirths,
        knownConditions: row.known_conditions,
      },
      serverSeq: Number(row.server_seq),
      syncedAt: row.synced_at,
    })),
  };
}

module.exports = { listForPortal };
