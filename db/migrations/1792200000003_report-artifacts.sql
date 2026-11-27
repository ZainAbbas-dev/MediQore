-- Up Migration

ALTER TABLE report_jobs
  ADD COLUMN area_id uuid REFERENCES areas (id),
  ADD COLUMN period_start date,
  ADD COLUMN period_end date,
  ADD COLUMN source_revision bigint,
  ADD COLUMN scope_snapshot jsonb,
  ADD COLUMN content_hash text,
  ADD COLUMN output_bytes bytea,
  ADD CONSTRAINT report_jobs_period_bounds CHECK (period_start <= period_end),
  ADD CONSTRAINT report_jobs_period_format_key UNIQUE (report_type, period, area_id, period_start, format);

CREATE INDEX report_jobs_listing_idx ON report_jobs (period, period_start DESC, area_id DESC)
  WHERE report_type = 'health_summary' AND area_id IS NOT NULL;

-- Invalidation commits with the source record, including a late insert, a date
-- correction, a soft deletion, and a move between areas. The worker compares
-- the resulting report content before replacing either artifact.
CREATE TABLE report_source_revisions (
  area_id uuid PRIMARY KEY REFERENCES areas (id),
  revision bigint NOT NULL DEFAULT 1
);

CREATE FUNCTION bump_report_revision(changed_area uuid) RETURNS void LANGUAGE sql AS $$
  INSERT INTO report_source_revisions (area_id) VALUES (changed_area)
  ON CONFLICT (area_id) DO UPDATE SET revision = report_source_revisions.revision + 1
$$;

CREATE FUNCTION invalidate_area_reports() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP <> 'DELETE' THEN
    PERFORM bump_report_revision(NEW.area_id);
  END IF;
  IF TG_OP = 'DELETE' OR (TG_OP = 'UPDATE' AND OLD.area_id IS DISTINCT FROM NEW.area_id) THEN
    PERFORM bump_report_revision(OLD.area_id);
  END IF;
  RETURN NULL;
END;
$$;

DO $$
DECLARE
  source text;
BEGIN
  FOREACH source IN ARRAY ARRAY[
    'households', 'women', 'pregnancies', 'pregnancy_outcomes', 'visits', 'risk_assessments',
    'referrals', 'emergency_alerts', 'alert_acknowledgements', 'anc_schedule', 'lhw_profiles',
    'children', 'immunisations', 'campaigns', 'campaign_household_status', 'campaign_child_doses',
    'revisits', 'refusals', 'nutrition_screenings'
  ] LOOP
    EXECUTE format('CREATE TRIGGER reports_invalidate AFTER INSERT OR UPDATE OR DELETE ON %I
      FOR EACH ROW EXECUTE FUNCTION invalidate_area_reports()', source);
  END LOOP;
END;
$$;

CREATE FUNCTION invalidate_reports_for_rules() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM bump_report_revision(id) FROM areas WHERE deleted_at IS NULL ORDER BY id;
  RETURN NULL;
END;
$$;

CREATE TRIGGER reports_invalidate AFTER INSERT OR UPDATE OR DELETE ON clinical_rules_versions
  FOR EACH STATEMENT EXECUTE FUNCTION invalidate_reports_for_rules();

CREATE FUNCTION invalidate_reports_for_lhw() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.role = 'lhw' OR OLD.role = 'lhw' THEN
    PERFORM bump_report_revision(relevant.area_id)
      FROM (
        SELECT area_id FROM lhw_profiles WHERE user_id = NEW.id
        UNION SELECT area_id FROM visits WHERE created_by = NEW.id
        UNION SELECT area_id FROM pregnancies WHERE created_by = NEW.id
      ) relevant ORDER BY relevant.area_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER reports_invalidate AFTER UPDATE OF full_name, deleted_at ON users
  FOR EACH ROW WHEN (OLD.full_name IS DISTINCT FROM NEW.full_name OR OLD.deleted_at IS DISTINCT FROM NEW.deleted_at)
  EXECUTE FUNCTION invalidate_reports_for_lhw();

ALTER TABLE audit_log DROP CONSTRAINT audit_log_action_check;
ALTER TABLE audit_log ADD CONSTRAINT audit_log_action_check
  CHECK (action IN ('create', 'edit', 'delete', 'referral', 'alert', 'login', 'sync_conflict', 'report_download'));

-- Down Migration

ALTER TABLE audit_log DROP CONSTRAINT audit_log_action_check;
-- Keep historical download audit rows intact on rollback, as the log is append-only.
ALTER TABLE audit_log ADD CONSTRAINT audit_log_action_check
  CHECK (action IN ('create', 'edit', 'delete', 'referral', 'alert', 'login', 'sync_conflict')) NOT VALID;

DROP TRIGGER reports_invalidate ON users;
DROP FUNCTION invalidate_reports_for_lhw();
DROP TRIGGER reports_invalidate ON clinical_rules_versions;
DROP FUNCTION invalidate_reports_for_rules();

DO $$
DECLARE
  source text;
BEGIN
  FOREACH source IN ARRAY ARRAY[
    'households', 'women', 'pregnancies', 'pregnancy_outcomes', 'visits', 'risk_assessments',
    'referrals', 'emergency_alerts', 'alert_acknowledgements', 'anc_schedule', 'lhw_profiles',
    'children', 'immunisations', 'campaigns', 'campaign_household_status', 'campaign_child_doses',
    'revisits', 'refusals', 'nutrition_screenings'
  ] LOOP
    EXECUTE format('DROP TRIGGER reports_invalidate ON %I', source);
  END LOOP;
END;
$$;

DROP FUNCTION invalidate_area_reports();
DROP FUNCTION bump_report_revision(uuid);
DROP TABLE report_source_revisions;
DROP INDEX report_jobs_listing_idx;
ALTER TABLE report_jobs DROP CONSTRAINT report_jobs_period_format_key, DROP CONSTRAINT report_jobs_period_bounds,
  DROP COLUMN area_id, DROP COLUMN period_start, DROP COLUMN period_end, DROP COLUMN source_revision,
  DROP COLUMN scope_snapshot, DROP COLUMN content_hash, DROP COLUMN output_bytes;
