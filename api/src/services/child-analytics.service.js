const db = require('../db/pool');
const { managedAreaIds } = require('./scope.service');
const { FILTERS, CHILDREN, EPI, NUTRITION, CAMPAIGNS, POLIO } = require('./child-analytics.queries');
const BUNDLED_RULES = require('../../../clinical-rules/clinical-rules.json');

// Operational display target for immunisation coverage, expressed as a percent.
const COVERAGE_THRESHOLD = 90;

async function scopeParams(client, viewer, filters) {
  return [
    await managedAreaIds(client, viewer), filters.districtId, filters.areaId, filters.tehsilId,
    filters.unionCouncilId, filters.lhwId, filters.startDate, filters.endDate, filters.days,
  ];
}

function pageOptions({ page = 1, limit = 25 }) {
  return { page, limit, offset: (page - 1) * limit };
}

async function filters(viewer, selection = {}, client = db) {
  const { rows: [result] } = await client.query(
    `WITH ${FILTERS}, ${CAMPAIGNS}
     SELECT array(SELECT DISTINCT jsonb_build_object('id', district_id, 'name', district_name) FROM places) AS districts,
            array(SELECT jsonb_build_object('id', id, 'name', name, 'districtId', district_id)
                  FROM places ORDER BY name, id) AS areas,
            array(SELECT DISTINCT ON (round_id) jsonb_build_object('id', round_id, 'name', name,
                         'startsOn', starts_on, 'endsOn', ends_on) FROM campaign_areas ORDER BY round_id, id) AS rounds`,
    await scopeParams(client, viewer, selection),
  );
  result.districts.sort((a, b) => a.name.localeCompare(b.name) || a.id.localeCompare(b.id));
  result.rounds.sort((a, b) => b.startsOn.localeCompare(a.startsOn) || a.name.localeCompare(b.name) || a.id.localeCompare(b.id));
  return result;
}

async function children(viewer, selection = {}, client = db) {
  const { page, limit, offset } = pageOptions(selection);
  const { rows: [result] } = await client.query(
    `WITH ${FILTERS}, ${CHILDREN}, ${EPI}, ${NUTRITION}, matching AS (
       SELECT c.*, coalesce(o.no_opv, false) AS no_opv, coalesce(v.zero_dose, false) AS zero_dose,
              coalesce(v.coverage_gap, false) AS coverage_gap
       FROM scoped_children c
       LEFT JOIN opv_status o ON o.child_id = c.id
       LEFT JOIN coverage_status v ON v.child_id = c.id
       WHERE ($11::text IS NULL OR CASE WHEN $11 = 'zero-dose' THEN v.zero_dose ELSE o.no_opv END)
     ), child_page AS (
       SELECT * FROM matching ORDER BY server_seq DESC LIMIT $12 OFFSET $13
     )
     SELECT s.as_of AS "asOf", (SELECT count(*)::int FROM matching) AS total,
            array(SELECT jsonb_build_object('id', c.id, 'name', c.name, 'sex', c.sex, 'dateOfBirth', c.date_of_birth,
                      'status', CASE WHEN c.active THEN 'active' ELSE 'deceased' END,
                      'areaId', c.area_id, 'areaName', c.area_name, 'village', c.village, 'householdId', c.household_id,
                      'householdNumber', c.household_number, 'syncedAt', c.synced_at,
                      'zeroDose', c.zero_dose, 'noOpv', c.no_opv, 'coverageGap', c.coverage_gap,
                      'latestScreening', CASE WHEN n.id IS NOT NULL THEN jsonb_build_object(
                         'screenedOn', n.screened_on, 'malnutritionClass', n.malnutrition_class,
                         'underweight', n.underweight, 'stunting', n.stunting) END)
                  FROM child_page c LEFT JOIN latest_screenings n ON n.child_id = c.id ORDER BY c.server_seq DESC) AS children
     FROM settings s`,
    [...await scopeParams(client, viewer, selection), BUNDLED_RULES, selection.followUp, limit, offset],
  );
  return { ...result, page, limit };
}

function withCoverage({ eligible, fullyVaccinated, ...row }) {
  const exact = eligible ? (fullyVaccinated * 100) / eligible : null;
  return {
    ...row, eligible, fullyVaccinated, percentage: exact === null ? null : Math.round(exact * 10) / 10,
    lowCoverage: exact !== null && exact < COVERAGE_THRESHOLD,
  };
}

async function coverage(viewer, selection = {}, client = db) {
  const { rows: [result] } = await client.query(
    `WITH ${FILTERS}, ${CHILDREN}, ${EPI},
     child_totals AS (
       SELECT o.area_id, count(*)::int AS total, count(*) FILTER (WHERE o.no_opv)::int AS no_opv,
              count(*) FILTER (WHERE v.zero_dose)::int AS zero_dose
       FROM opv_status o JOIN coverage_status v ON v.child_id = o.child_id
       GROUP BY GROUPING SETS ((o.area_id), ())
     ), enabled_antigens AS (
       SELECT DISTINCT p.id AS area_id, d.antigen FROM places p CROSS JOIN doses d
       WHERE NOT d.rollout_by_area OR d.enabled_area_ids ? p.id::text
     ), coverage_totals AS (
       SELECT e.area_id, e.antigen, count(a.child_id)::int AS eligible,
              count(a.child_id) FILTER (WHERE a.fully_vaccinated)::int AS fully_vaccinated
       FROM enabled_antigens e LEFT JOIN antigen_status a ON a.area_id = e.area_id AND a.antigen = e.antigen
       GROUP BY GROUPING SETS ((e.area_id, e.antigen), (e.antigen))
     ), antigen_totals AS (
       SELECT area_id, jsonb_agg(jsonb_build_object('antigen', antigen, 'eligible', eligible,
                 'fullyVaccinated', fully_vaccinated) ORDER BY antigen) AS antigens
       FROM coverage_totals GROUP BY area_id
     )
     SELECT e.as_of AS "asOf", e.schedule->>'schedule_version' AS "scheduleVersion", e.review_status AS "reviewStatus",
            c.total AS "totalChildren", c.zero_dose AS "zeroDose", c.no_opv AS "noOpv",
            coalesce(a.antigens, '[]') AS antigens,
            array(SELECT jsonb_build_object('areaId', p.id, 'areaName', p.name, 'totalChildren', coalesce(ct.total, 0),
                       'zeroDose', coalesce(ct.zero_dose, 0), 'noOpv', coalesce(ct.no_opv, 0),
                       'antigens', coalesce(at.antigens, '[]'))
                  FROM places p LEFT JOIN child_totals ct ON ct.area_id = p.id
                  LEFT JOIN antigen_totals at ON at.area_id = p.id ORDER BY p.name, p.id) AS areas
     FROM epi e CROSS JOIN child_totals c LEFT JOIN antigen_totals a ON a.area_id IS NULL
     WHERE c.area_id IS NULL`,
    [...await scopeParams(client, viewer, selection), BUNDLED_RULES],
  );
  return {
    ...result, coverageThreshold: COVERAGE_THRESHOLD, antigens: result.antigens.map(withCoverage),
    areas: result.areas.map((area) => ({ ...area, antigens: area.antigens.map(withCoverage) })),
  };
}

async function polio(viewer, selection = {}, client = db) {
  const { page, limit, offset } = pageOptions(selection);
  const { rows: [result] } = await client.query(
    `WITH ${FILTERS}, ${CHILDREN}, ${CAMPAIGNS}, ${POLIO},
     no_opv_by_area AS (
       SELECT area_id, count(*) FILTER (WHERE no_opv)::int AS total FROM opv_status GROUP BY area_id
     ), visible_areas AS (
       SELECT p.* FROM places p WHERE $10::uuid IS NULL OR EXISTS (SELECT 1 FROM round_areas r WHERE r.area_id = p.id)
     ), rounds AS (
       SELECT DISTINCT ON (round_id) round_id, name, starts_on, ends_on FROM round_areas ORDER BY round_id, id
     ), progress_totals AS (
       SELECT area_id, round_id, count(*)::int AS "householdsVisited",
         coalesce(sum(children_under_5), 0)::int AS "childrenEligible",
         coalesce(sum(children_vaccinated), 0)::int AS "childrenVaccinated",
         coalesce(sum(refusals), 0)::int AS refusals,
         count(*) FILTER (WHERE status = 'all_vaccinated')::int AS "allVaccinatedHouseholds",
         count(*) FILTER (WHERE status = 'partially_covered')::int AS "partialHouseholds",
         count(*) FILTER (WHERE status = 'refusal')::int AS "refusalHouseholds",
         count(*) FILTER (WHERE status = 'not_available')::int AS "notAvailableHouseholds",
         count(*) FILTER (WHERE status = 'no_eligible_child')::int AS "noEligibleHouseholds"
       FROM campaign_households GROUP BY GROUPING SETS ((area_id), (round_id), ())
     ), progress AS (
       SELECT area_id, round_id, to_jsonb(t) - 'area_id' - 'round_id' AS stats FROM progress_totals t
     ), overall AS (
       SELECT stats, jsonb_object_agg(k, 0) AS empty_stats FROM progress, jsonb_object_keys(stats) AS k
       WHERE area_id IS NULL AND round_id IS NULL GROUP BY stats
     )
     SELECT s.as_of AS "asOf", (o.stats->>'householdsVisited')::int AS total,
            o.stats || jsonb_build_object('noOpv', (SELECT coalesce(sum(n.total), 0) FROM no_opv_by_area n
                         JOIN visible_areas a ON a.id = n.area_id)) AS summary,
            array(SELECT jsonb_build_object('areaId', a.id, 'areaName', a.name, 'noOpv', coalesce(n.total, 0))
                         || coalesce(p.stats, o.empty_stats)
                  FROM visible_areas a LEFT JOIN progress p ON p.area_id = a.id
                  LEFT JOIN no_opv_by_area n ON n.area_id = a.id ORDER BY a.name, a.id) AS areas,
            array(SELECT jsonb_build_object('id', r.round_id, 'name', r.name, 'startsOn', r.starts_on, 'endsOn', r.ends_on,
                         'noOpv', (SELECT coalesce(sum(n.total), 0) FROM no_opv_by_area n JOIN round_areas ra
                                  ON ra.area_id = n.area_id AND ra.round_id = r.round_id)) || coalesce(p.stats, o.empty_stats)
                  FROM rounds r LEFT JOIN progress p ON p.round_id = r.round_id
                  ORDER BY r.starts_on DESC, r.name, r.round_id) AS rounds,
            array(SELECT jsonb_build_object('id', id, 'roundId', round_id, 'roundName', round_name,
                      'areaId', area_id, 'areaName', area_name, 'householdId', household_id, 'village', village,
                      'householdNumber', household_number, 'visitedOn', visited_on, 'status', status,
                      'childrenEligible', children_under_5, 'childrenVaccinated', children_vaccinated,
                      'refusals', refusals, 'refusalReasons', refusal_reasons, 'nextRevisitOn', next_revisit_on)
                  FROM campaign_households ORDER BY visited_on DESC, server_seq DESC LIMIT $11 OFFSET $12) AS households
     FROM settings s CROSS JOIN overall o`,
    [...await scopeParams(client, viewer, selection), selection.roundId, selection.breakdownOnly ? 0 : limit, offset],
  );
  return { ...result, page, limit };
}

async function nutrition(viewer, selection = {}, client = db) {
  const { rows: [result] } = await client.query(
    `WITH ${FILTERS}, ${CHILDREN}, ${NUTRITION}
     SELECT (SELECT count(*)::int FROM screenings) AS screenings, count(*)::int AS "childrenScreened",
            count(*) FILTER (WHERE malnutrition_class = 'sam')::int AS sam,
            count(*) FILTER (WHERE malnutrition_class = 'mam')::int AS mam,
            count(*) FILTER (WHERE malnutrition_class = 'normal')::int AS normal,
            count(*) FILTER (WHERE underweight)::int AS underweight,
            count(*) FILTER (WHERE stunting)::int AS stunting
     FROM latest_screenings`,
    await scopeParams(client, viewer, selection),
  );
  return result;
}

async function hotspots(viewer, selection = {}, client = db) {
  const { page, limit, offset } = pageOptions({ ...selection, limit: selection.limit ?? 500 });
  const { rows: [result] } = await client.query(
    `WITH ${FILTERS}, ${CHILDREN}, ${EPI}, ${NUTRITION},
     household_counts AS (
       SELECT c.household_id AS id, c.area_id, c.area_name, c.village, c.latitude, c.longitude,
              count(*) FILTER (WHERE n.malnutrition_class = 'sam')::int AS sam,
              count(*) FILTER (WHERE n.malnutrition_class = 'mam')::int AS mam,
              count(*) FILTER (WHERE n.underweight)::int AS underweight,
              count(*) FILTER (WHERE n.stunting)::int AS stunting,
              count(*) FILTER (WHERE o.no_opv)::int AS no_opv,
              count(*) FILTER (WHERE v.zero_dose)::int AS zero_dose,
              count(*) FILTER (WHERE v.coverage_gap)::int AS coverage_gaps
       FROM scoped_children c
       LEFT JOIN opv_status o ON o.child_id = c.id
       LEFT JOIN coverage_status v ON v.child_id = c.id
       LEFT JOIN latest_screenings n ON n.child_id = c.id
       WHERE c.active AND c.latitude IS NOT NULL
       GROUP BY c.household_id, c.area_id, c.area_name, c.village, c.latitude, c.longitude
     ), matching AS (
       SELECT * FROM household_counts WHERE sam + mam + stunting + underweight + no_opv + zero_dose + coverage_gaps > 0
     )
     SELECT (SELECT count(*)::int FROM matching) AS total,
            array(SELECT jsonb_build_object('id', id, 'areaId', area_id, 'areaName', area_name, 'village', village,
                       'latitude', latitude, 'longitude', longitude, 'sam', sam, 'mam', mam, 'underweight', underweight,
                       'stunting', stunting, 'coverageGaps', coverage_gaps, 'zeroDose', zero_dose, 'noOpv', no_opv)
                  FROM matching ORDER BY sam DESC, mam DESC, coverage_gaps DESC, id LIMIT $11 OFFSET $12) AS households`,
    [...await scopeParams(client, viewer, selection), BUNDLED_RULES, limit, offset],
  );
  return { ...result, page, limit };
}

module.exports = { filters, children, coverage, polio, nutrition, hotspots };
