const child = require('./child-analytics.service');

// The model and rule result are already combined in risk_assessments.final_level.
// Periods are inclusive Pakistan calendar dates. Timestamp queries use a
// half-open range, so a visit at midnight belongs to exactly one period.
async function maternalData(client, areaId, start, end) {
  const { rows: [result] } = await client.query(
    `WITH bounds AS (
       SELECT $2::date AS begins, $3::date AS ends,
              $2::date::timestamp AT TIME ZONE 'Asia/Karachi' AS starts_at,
              ($3::date + 1)::timestamp AT TIME ZONE 'Asia/Karachi' AS stops_at
     ), pregnancy_scope AS (
       SELECT p.*, w.patient_code FROM pregnancies p
       JOIN women w ON w.id = p.woman_id AND w.area_id = p.area_id AND w.deleted_at IS NULL
       WHERE p.area_id = $1 AND p.deleted_at IS NULL
     ), registered AS (
       SELECT p.* FROM pregnancy_scope p CROSS JOIN bounds b WHERE p.registered_on BETWEEN b.begins AND b.ends
     ), period_visits AS (
       SELECT v.*, p.woman_id, p.patient_code FROM visits v
       JOIN pregnancy_scope p ON p.id = v.pregnancy_id AND p.area_id = v.area_id CROSS JOIN bounds b
       WHERE v.deleted_at IS NULL AND v.visited_at >= b.starts_at AND v.visited_at < b.stops_at
     ), red_cases AS (
       SELECT DISTINCT ON (v.woman_id) v.patient_code AS "patientCode",
              (v.visited_at AT TIME ZONE 'Asia/Karachi')::date AS "visitedOn",
              bool_or(r.is_emergency) OVER (PARTITION BY v.woman_id) AS emergency
       FROM period_visits v JOIN risk_assessments r
         ON r.visit_id = v.id AND r.area_id = v.area_id AND r.pregnancy_id = v.pregnancy_id
        AND r.deleted_at IS NULL AND r.final_level = 'red'
       ORDER BY v.woman_id, v.visited_at DESC, v.server_seq DESC
     ), period_referrals AS (
       SELECT r.*, b.stops_at FROM referrals r
       JOIN pregnancy_scope p ON p.id = r.pregnancy_id AND p.area_id = r.area_id CROSS JOIN bounds b
       WHERE r.deleted_at IS NULL AND r.referred_at >= b.starts_at AND r.referred_at < b.stops_at
     ), open_alerts AS (
       SELECT a.id FROM emergency_alerts a
       JOIN pregnancy_scope p ON p.id = a.pregnancy_id AND p.area_id = a.area_id CROSS JOIN bounds b
       LEFT JOIN LATERAL (
         SELECT min(acknowledged_at) AS at FROM alert_acknowledgements ack
         WHERE ack.alert_id = a.id AND ack.area_id = a.area_id AND ack.deleted_at IS NULL
       ) ack ON true
       WHERE a.deleted_at IS NULL AND a.raised_at >= b.starts_at AND a.raised_at < b.stops_at
         AND (ack.at >= b.stops_at OR (ack.at IS NULL AND a.status <> 'acknowledged'))
     ), anc AS (
       SELECT v.visited_at AS completed_at, b.stops_at FROM anc_schedule a
       JOIN pregnancy_scope p ON p.id = a.pregnancy_id AND p.area_id = a.area_id CROSS JOIN bounds b
       LEFT JOIN visits v ON v.id = a.completed_visit_id AND v.area_id = a.area_id
        AND v.pregnancy_id = p.id AND v.deleted_at IS NULL
       WHERE a.deleted_at IS NULL AND a.due_on BETWEEN b.begins AND b.ends
     ), outcome_counts AS (
       SELECT o.outcome_type AS outcome, count(*)::int AS count FROM pregnancy_outcomes o
       JOIN pregnancy_scope p ON p.id = o.pregnancy_id AND p.area_id = o.area_id CROSS JOIN bounds b
       WHERE o.deleted_at IS NULL AND o.outcome_on BETWEEN b.begins AND b.ends GROUP BY o.outcome_type
     ), visit_counts AS (
       SELECT created_by AS id, count(*)::int AS count FROM period_visits GROUP BY created_by
     ), registration_counts AS (
       SELECT created_by AS id, count(*)::int AS count FROM registered GROUP BY created_by
     ), workers AS (
       SELECT p.user_id AS id FROM lhw_profiles p CROSS JOIN bounds b
       WHERE p.area_id = $1 AND p.deleted_at IS NULL AND p.created_at < b.stops_at
       UNION SELECT id FROM visit_counts
       UNION SELECT id FROM registration_counts
     ), activity AS (
       SELECT coalesce(p.lhw_code, u.username) AS "lhwCode", u.full_name AS "fullName",
              coalesce(v.count, 0) AS visits, coalesce(r.count, 0) AS registrations
       FROM workers w JOIN users u ON u.id = w.id AND u.role = 'lhw'
       LEFT JOIN lhw_profiles p ON p.user_id = w.id
       LEFT JOIN visit_counts v ON v.id = w.id
       LEFT JOIN registration_counts r ON r.id = w.id
     )
     SELECT jsonb_build_object(
              'registrations', (SELECT count(*) FROM registered),
              'womenRegistered', (SELECT count(DISTINCT woman_id) FROM registered),
              'visits', (SELECT count(*) FROM period_visits),
              'highRisk', (SELECT count(*) FROM red_cases),
              'emergencies', (SELECT count(*) FROM red_cases WHERE emergency),
              'referrals', (SELECT count(*) FROM period_referrals),
              'referralsAttended', (SELECT count(*) FROM period_referrals
                WHERE attended AND (outcome_recorded_at IS NULL OR outcome_recorded_at < stops_at)),
              'unacknowledgedAlerts', (SELECT count(*) FROM open_alerts),
              'ancDue', (SELECT count(*) FROM anc),
              'ancMissed', (SELECT count(*) FROM anc WHERE completed_at IS NULL OR completed_at >= stops_at)
            ) AS maternal,
            coalesce((SELECT jsonb_agg(red_cases ORDER BY "visitedOn" DESC, "patientCode") FROM red_cases), '[]') AS risk,
            coalesce((SELECT jsonb_agg(outcome_counts ORDER BY outcome) FROM outcome_counts), '[]') AS outcomes,
            coalesce((SELECT jsonb_agg(activity ORDER BY "lhwCode") FROM activity), '[]') AS activity`,
    [areaId, start, end],
  );
  return result;
}

async function collectReport(client, { area, period, periodStart, periodEnd }) {
  const viewer = { role: 'admin' };
  const dates = { areaId: area.id, startDate: periodStart, endDate: periodEnd };
  const maternal = await maternalData(client, area.id, periodStart, periodEnd);
  const { scheduleVersion, zeroDose, noOpv, antigens, coverageThreshold } = await child.coverage(viewer, dates, client);
  const { summary, rounds } = await child.polio(viewer, { ...dates, breakdownOnly: true }, client);
  const nutrition = await child.nutrition(viewer, dates, client);
  return {
    area, period, periodStart, periodEnd, ...maternal,
    coverage: { scheduleVersion, zeroDose, noOpv, antigens, coverageThreshold }, polio: { summary, rounds }, nutrition,
  };
}

module.exports = { collectReport };
