// Area membership is checked for the record and its parent. Dates are local to
// Pakistan and the end date includes the whole reporting day.
const FILTERS = `input AS (
  SELECT $1::uuid[] AS area_ids, $2::uuid AS district_id, $3::uuid AS area_id,
         $4::uuid AS tehsil_id, $5::uuid AS union_council_id, $6::uuid AS lhw_id,
         $7::date AS start_date, $9::int AS days,
         least($8::date, (now() AT TIME ZONE 'Asia/Karachi')::date) AS as_of
), settings AS (
  SELECT *, coalesce(start_date, as_of - (days - 1)) AS since FROM input
), places AS (
  SELECT a.id, a.name, d.id AS district_id, d.name AS district_name
  FROM areas a
  JOIN union_councils uc ON uc.id = a.union_council_id AND uc.deleted_at IS NULL
  JOIN tehsils t ON t.id = uc.tehsil_id AND t.deleted_at IS NULL
  JOIN districts d ON d.id = t.district_id AND d.deleted_at IS NULL
  CROSS JOIN settings s
  WHERE a.deleted_at IS NULL
    AND (s.area_ids IS NULL OR a.id = ANY(s.area_ids))
    AND (s.district_id IS NULL OR d.id = s.district_id)
    AND (s.area_id IS NULL OR a.id = s.area_id)
    AND (s.tehsil_id IS NULL OR t.id = s.tehsil_id)
    AND (s.union_council_id IS NULL OR uc.id = s.union_council_id)
)`;

const CHILDREN = `scoped_children AS (
  SELECT c.id, c.name, c.sex, c.date_of_birth, c.deceased_on, c.synced_at, c.server_seq,
         p.id AS area_id, p.name AS area_name, h.id AS household_id, h.village,
         h.household_number, h.latitude, h.longitude, s.as_of,
         c.deceased_on IS NULL OR c.deceased_on > s.as_of AS active
  FROM children c
  JOIN places p ON p.id = c.area_id
  JOIN households h ON h.id = c.household_id AND h.area_id = c.area_id AND h.deleted_at IS NULL
  CROSS JOIN settings s
  WHERE c.deleted_at IS NULL AND c.date_of_birth <= s.as_of
    AND (s.lhw_id IS NULL OR c.created_by = s.lhw_id)
), under_five AS (
  SELECT * FROM scoped_children WHERE active AND as_of < date_of_birth + interval '5 years'
), routine_doses AS (
  SELECT i.child_id, lower(i.antigen) AS antigen, i.dose_number
  FROM under_five c
  JOIN immunisations i ON i.child_id = c.id AND i.area_id = c.area_id
  WHERE i.deleted_at IS NULL AND i.given_on BETWEEN c.date_of_birth AND c.as_of
), opv_status AS (
  SELECT c.id AS child_id, c.area_id,
         NOT EXISTS (SELECT 1 FROM routine_doses r WHERE r.child_id = c.id AND r.antigen = 'opv')
         AND NOT EXISTS (
           SELECT 1 FROM campaign_child_doses d
           JOIN campaigns a ON a.id = d.campaign_id AND a.area_id = d.area_id AND a.deleted_at IS NULL
           JOIN campaign_household_status h ON h.id = d.campaign_household_status_id
             AND h.area_id = d.area_id AND h.campaign_id = d.campaign_id AND h.deleted_at IS NULL
           WHERE d.child_id = c.id AND d.area_id = c.area_id AND d.deleted_at IS NULL
             AND d.vaccine_type = 'OPV' AND h.household_id = c.household_id
             AND d.given_on BETWEEN c.date_of_birth AND c.as_of
             AND d.given_on BETWEEN a.starts_on AND a.ends_on
         ) AS no_opv
  FROM under_five c
)`;

const EPI = `clinical_rules AS (
  SELECT s.as_of, coalesce(v.content, $10::jsonb) AS content,
         coalesce(v.review_status, replace($10::jsonb->>'status', ' ', '_')) AS review_status
  FROM settings s
  LEFT JOIN LATERAL (
    SELECT content, review_status FROM clinical_rules_versions
    WHERE review_status <> 'retired' AND effective_from <= s.as_of
      AND (content->'epi_schedule'->>'effective_from')::date <= s.as_of
    ORDER BY effective_from DESC, created_at DESC, id DESC LIMIT 1
  ) v ON true
), epi AS (
  SELECT as_of, content->'epi_schedule' AS schedule, review_status FROM clinical_rules
), doses AS (
  SELECT d.antigen, d.dose_number, d.rollout_by_area, d.enabled_area_ids,
         make_interval(
           years => coalesce((d.recommended_age->>'years')::int, 0),
           months => coalesce((d.recommended_age->>'months')::int, 0),
           weeks => coalesce((d.recommended_age->>'weeks')::int, 0),
           days => coalesce((d.recommended_age->>'days')::int, 0)
         ) AS due_age,
         d.antigen = epi.schedule->'zero_dose_indicator'->>'antigen'
           AND d.dose_number = (epi.schedule->'zero_dose_indicator'->>'dose_number')::int AS zero_dose_indicator
  FROM epi
  CROSS JOIN LATERAL jsonb_to_recordset(epi.schedule->'doses') AS d(
    antigen text, dose_number int, rollout_by_area boolean, enabled_area_ids jsonb, recommended_age jsonb
  )
  WHERE (epi.schedule->>'effective_from')::date <= epi.as_of
), required_doses AS (
  SELECT c.id AS child_id, c.area_id, d.antigen, d.dose_number, d.zero_dose_indicator,
         (c.date_of_birth + d.due_age)::date AS due_on, r.child_id IS NOT NULL AS recorded,
         c.as_of, c.as_of < c.date_of_birth + interval '2 years' AS under_two
  FROM under_five c
  CROSS JOIN doses d
  LEFT JOIN routine_doses r ON r.child_id = c.id AND r.antigen = lower(d.antigen) AND r.dose_number = d.dose_number
  WHERE NOT d.rollout_by_area OR d.enabled_area_ids ? c.area_id::text
), antigen_status AS (
  SELECT child_id, area_id, antigen, bool_and(recorded) AS fully_vaccinated
  FROM required_doses WHERE under_two
  GROUP BY child_id, area_id, antigen HAVING max(due_on) <= max(as_of)
), coverage_status AS (
  SELECT id AS child_id,
         EXISTS (SELECT 1 FROM antigen_status a WHERE a.child_id = c.id AND NOT a.fully_vaccinated) AS coverage_gap,
         EXISTS (SELECT 1 FROM required_doses d WHERE d.child_id = c.id AND d.zero_dose_indicator
                   AND d.due_on < d.as_of AND NOT d.recorded) AS zero_dose
  FROM under_five c
)`;

const NUTRITION = `screenings AS (
  SELECT n.*, c.household_id
  FROM scoped_children c
  JOIN nutrition_screenings n ON n.child_id = c.id AND n.area_id = c.area_id
  CROSS JOIN settings s
  WHERE n.deleted_at IS NULL AND n.screened_on BETWEEN c.date_of_birth AND s.as_of
    AND n.screened_on < c.date_of_birth + interval '5 years'
    AND (c.deceased_on IS NULL OR n.screened_on <= c.deceased_on)
    AND (s.since IS NULL OR n.screened_on >= s.since)
), latest_screenings AS (
  SELECT DISTINCT ON (child_id) * FROM screenings ORDER BY child_id, screened_on DESC, server_seq DESC
)`;

const CAMPAIGNS = `campaign_areas AS (
  SELECT c.id, coalesce(c.round_id, c.id) AS round_id, c.area_id, c.name, c.starts_on, c.ends_on
  FROM campaigns c JOIN places p ON p.id = c.area_id
  WHERE c.deleted_at IS NULL
)`;

const POLIO = `round_areas AS (
  SELECT c.* FROM campaign_areas c CROSS JOIN settings s
  WHERE c.starts_on <= s.as_of AND (s.since IS NULL OR c.ends_on >= s.since)
    AND ($10::uuid IS NULL OR c.round_id = $10)
), latest_visits AS (
  SELECT DISTINCT ON (c.round_id, r.household_id)
         c.round_id, c.name AS round_name, r.id, r.area_id, p.name AS area_name, r.household_id,
         h.village, h.household_number, r.visited_on, r.server_seq, r.children_under_5, r.children_vaccinated,
         CASE WHEN r.children_under_5 = 0 AND r.status <> 'not_available' THEN 'no_eligible_child'
              WHEN r.status = 'not_available' AND r.children_vaccinated = 0 THEN 'not_available'
              WHEN r.children_vaccinated = r.children_under_5 THEN 'all_vaccinated'
              WHEN r.children_vaccinated > 0 THEN 'partially_covered'
              ELSE r.status END AS status
  FROM round_areas c
  JOIN campaign_household_status r ON r.campaign_id = c.id AND r.area_id = c.area_id
  JOIN places p ON p.id = r.area_id
  JOIN households h ON h.id = r.household_id AND h.area_id = r.area_id AND h.deleted_at IS NULL
  CROSS JOIN settings s
  WHERE r.deleted_at IS NULL AND r.vaccine_type = 'OPV'
    AND r.visited_on BETWEEN c.starts_on AND least(c.ends_on, s.as_of)
    AND (s.since IS NULL OR r.visited_on >= s.since)
    AND (s.lhw_id IS NULL OR r.created_by = s.lhw_id)
  ORDER BY c.round_id, r.household_id, r.visited_on DESC, r.server_seq DESC
), campaign_households AS (
  SELECT v.*, r.refusals, r.refusal_reasons,
         (SELECT min(re.scheduled_on) FROM revisits re
          WHERE re.campaign_household_status_id = v.id AND re.area_id = v.area_id AND re.deleted_at IS NULL
            AND (re.completed_at IS NULL OR (re.completed_at AT TIME ZONE 'Asia/Karachi')::date > s.as_of)) AS next_revisit_on
  FROM latest_visits v CROSS JOIN settings s
  CROSS JOIN LATERAL (
    SELECT count(*)::int AS refusals, coalesce(array_agg(DISTINCT rr.reason ORDER BY rr.reason), '{}') AS refusal_reasons
    FROM refusals rr WHERE rr.campaign_household_status_id = v.id AND rr.area_id = v.area_id AND rr.deleted_at IS NULL
  ) r
)`;

module.exports = { FILTERS, CHILDREN, EPI, NUTRITION, CAMPAIGNS, POLIO };
