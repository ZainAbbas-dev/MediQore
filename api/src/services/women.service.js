const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { supervisorAreaIds } = require('./scope.service');
const { TABLES, normalise, weeksOn } = require('../sync/tables');

// Today's date in Pakistan (UTC+5, no daylight saving).
const pakistanToday = () => new Date(Date.now() + 5 * 60 * 60 * 1000).toISOString().slice(0, 10);

// M2 FE-1, FE-2: registered women for the portal (M10 FE-1 shows registered
// patients), with how many visits each has had (M3 FE-1). A supervisor sees only their assigned areas, an admin sees all.
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
            p.estimated_delivery_date, p.edd_basis,
            o.previous_pregnancies, o.previous_c_sections, o.stillbirths, o.known_conditions,
            v.visit_count, v.last_visit_at,
            count(*) OVER () AS total
     FROM women w
     JOIN areas a ON a.id = w.area_id
     JOIN households h ON h.id = w.household_id
     JOIN users u ON u.id = w.created_by
     LEFT JOIN lhw_profiles lp ON lp.user_id = w.created_by
     LEFT JOIN LATERAL (
       SELECT registered_on, pregnancy_month_at_registration, status, estimated_delivery_date, edd_basis FROM pregnancies
       WHERE woman_id = w.id AND deleted_at IS NULL
       ORDER BY (status = 'active') DESC, server_seq DESC LIMIT 1
     ) p ON true
     LEFT JOIN obstetric_history o ON o.woman_id = w.id AND o.deleted_at IS NULL
     LEFT JOIN LATERAL (
       SELECT count(*) AS visit_count, max(vi.visited_at) AS last_visit_at
       FROM visits vi JOIN pregnancies pv ON pv.id = vi.pregnancy_id
       WHERE pv.woman_id = w.id AND vi.deleted_at IS NULL
     ) v ON true
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
        // M2 FE-1: estimated delivery date and today's gestational age (Pakistan date).
        estimatedDeliveryDate: row.estimated_delivery_date,
        eddBasis: row.edd_basis,
        gestationalWeeks: Math.floor(weeksOn(row.estimated_delivery_date, pakistanToday())),
      },
      obstetricHistory: row.previous_pregnancies === null ? null : {
        previousPregnancies: row.previous_pregnancies,
        previousCSections: row.previous_c_sections,
        stillbirths: row.stillbirths,
        knownConditions: row.known_conditions,
      },
      visits: { count: Number(row.visit_count), lastVisitAt: row.last_visit_at },
      serverSeq: Number(row.server_seq),
      syncedAt: row.synced_at,
    })),
  };
}

// GET /women/:id/visits (M10 FE-1, M3 FE-1): every visit of one woman, over all
// her pregnancies, for the portal, with the same fields the phone sends. The
// latest first by server number, never by the phone's clock (LI-7). A woman
// outside a supervisor's areas is not found.
async function visitsForPortal(user, womanId) {
  const params = [womanId];
  let inScope = '';
  if (user.role === 'supervisor') {
    params.push(await supervisorAreaIds(db, user.id));
    inScope = 'AND area_id = ANY($2)';
  }
  const { rows: [woman] } = await db.query(
    `SELECT id FROM women WHERE id = $1 AND deleted_at IS NULL ${inScope}`,
    params,
  );
  if (!woman) throw new AppError(404, 'NOT_FOUND', 'No registered woman with this ID in your areas');

  const { fields } = TABLES.visits;
  const { rows } = await db.query(
    `SELECT v.*, lp.lhw_code AS recorded_by_code, u.full_name AS recorded_by_name
     FROM visits v
     JOIN pregnancies p ON p.id = v.pregnancy_id
     LEFT JOIN users u ON u.id = v.created_by
     LEFT JOIN lhw_profiles lp ON lp.user_id = v.created_by
     WHERE p.woman_id = $1 AND v.deleted_at IS NULL
     ORDER BY v.server_seq DESC`,
    [womanId],
  );
  return {
    visits: rows.map((row) => ({
      id: row.id,
      ...Object.fromEntries(Object.entries(fields).map(([name, field]) => [name, normalise(field, row[field.column])])),
      recordedBy: { lhwCode: row.recorded_by_code, fullName: row.recorded_by_name },
      serverSeq: Number(row.server_seq),
      syncedAt: row.synced_at,
    })),
  };
}

module.exports = { listForPortal, visitsForPortal };
