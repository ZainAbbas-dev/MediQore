-- Up Migration

CREATE INDEX child_analytics_campaign_visit_period
  ON campaign_household_status (campaign_id, visited_on DESC, server_seq DESC)
  WHERE deleted_at IS NULL AND vaccine_type = 'OPV';

CREATE INDEX child_analytics_nutrition_screening_period
  ON nutrition_screenings (child_id, screened_on DESC, server_seq DESC)
  WHERE deleted_at IS NULL;

-- Down Migration

DROP INDEX child_analytics_nutrition_screening_period;
DROP INDEX child_analytics_campaign_visit_period;
