const db = require('../db/pool');
const { and, placeConditions, scopedAreaIds } = require('./dashboard.service');

const TODAY = "(now() AT TIME ZONE 'Asia/Karachi')::date";

async function maternal(viewer, { limit = 15, offset = 0, ...filters }) {
  const scope = { ...filters, areaIds: await scopedAreaIds(viewer) };
  const params = [limit, offset];
  const risk = placeConditions(params, scope, 'r.area_id', 'r.created_by', 'v.visited_at');
  const alerts = placeConditions(params, scope, 'e.area_id', 'e.created_by', 'e.raised_at');
  const referrals = placeConditions(params, scope, 'f.area_id', 'f.created_by', 'f.referred_at');
  const facilities = placeConditions(params, scope, 'a.id', null);
  if (filters.lhwId) {
    params.push(filters.lhwId);
    facilities.push(`EXISTS (SELECT 1 FROM lhw_profiles p WHERE p.area_id = a.id AND p.deleted_at IS NULL AND p.user_id = $${params.length})`);
  }
  const { rows: [data] } = await db.query(
    `WITH latest_risk AS (
       SELECT DISTINCT ON (p.id) r.id, r.final_level, r.is_emergency, r.server_seq, v.visited_at,
         w.patient_code, w.name, a.name AS area_name
       FROM risk_assessments r
       JOIN visits v ON v.id = r.visit_id AND v.pregnancy_id = r.pregnancy_id AND v.area_id = r.area_id AND v.deleted_at IS NULL
       JOIN pregnancies p ON p.id = r.pregnancy_id AND p.area_id = r.area_id AND p.deleted_at IS NULL AND p.status = 'active'
       JOIN women w ON w.id = p.woman_id AND w.area_id = p.area_id AND w.deleted_at IS NULL
       JOIN areas a ON a.id = r.area_id AND a.deleted_at IS NULL
       WHERE r.deleted_at IS NULL AND v.visited_at <= now()${and(risk)}
       ORDER BY p.id, v.visited_at DESC, r.server_seq DESC
     ), high_risk AS (
       SELECT id, patient_code AS "patientCode", name, area_name AS area, is_emergency AS emergency, visited_at AS "visitedAt", server_seq
       FROM latest_risk WHERE final_level = 'red'
       ORDER BY visited_at DESC, server_seq DESC LIMIT $1 OFFSET $2
     ), referral_counts AS (
       SELECT count(*)::int AS total,
              count(*) FILTER (WHERE f.attended IS TRUE)::int AS completed,
              count(*) FILTER (WHERE f.outcome_recorded_at IS NULL AND f.follow_up_due_on < ${TODAY})::int AS overdue
       FROM referrals f WHERE f.deleted_at IS NULL AND f.referred_at <= now()${and(referrals)}
     ), places AS (
       SELECT a.id, t.district_id FROM areas a JOIN union_councils uc ON uc.id = a.union_council_id
       JOIN tehsils t ON t.id = uc.tehsil_id WHERE a.deleted_at IS NULL${and(facilities)}
     ), facility_points AS (
       SELECT f.id, f.name, f.latitude::float, f.longitude::float, f.type
       FROM (
         SELECT id, name, latitude, longitude, area_id, district_id, facility_type AS type FROM hospitals WHERE deleted_at IS NULL
         UNION ALL
         SELECT id, name, latitude, longitude, area_id, district_id, centre_type AS type FROM referral_centres WHERE deleted_at IS NULL
       ) f
       WHERE f.latitude IS NOT NULL AND f.longitude IS NOT NULL
         AND EXISTS (SELECT 1 FROM places p WHERE (f.area_id = p.id OR (f.area_id IS NULL AND f.district_id = p.district_id)))
       ORDER BY f.name, f.id
     )
     SELECT (SELECT jsonb_build_object(
              'green', count(*) FILTER (WHERE final_level = 'green'),
              'yellow', count(*) FILTER (WHERE final_level = 'yellow'),
              'red', count(*) FILTER (WHERE final_level = 'red')
            ) FROM latest_risk) AS "riskDistribution",
            (SELECT coalesce(jsonb_agg(to_jsonb(h) - 'server_seq' ORDER BY h."visitedAt" DESC, h.server_seq DESC), '[]') FROM high_risk h) AS "highRisk",
            (SELECT to_jsonb(f) FROM referral_counts f) AS referrals,
            (SELECT count(*)::int FROM emergency_alerts e
             WHERE e.deleted_at IS NULL AND e.status IN ('open','escalated') AND e.raised_at <= now()
               AND NOT EXISTS (SELECT 1 FROM alert_acknowledgements aa WHERE aa.alert_id = e.id AND aa.area_id = e.area_id AND aa.deleted_at IS NULL)
               ${and(alerts)}) AS "unacknowledgedAlerts",
            (SELECT coalesce(jsonb_agg(f ORDER BY f.name, f.id), '[]') FROM facility_points f) AS facilities`,
    params,
  );
  return { ...data, limit, offset };
}

module.exports = { maternal };
