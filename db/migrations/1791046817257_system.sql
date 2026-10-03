-- Up Migration

-- System tables (Phase 0–1; used by M3, M10): audit log, sync conflicts, report jobs.

-- Every create, edit, delete, referral, alert and login (M10 FE-3), every emergency
-- alert attempt with channel and delivery status (M5 FE-2), and every conflicted
-- sync record (M3 FE-2). Append-only.
CREATE TABLE audit_log (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  user_id     uuid REFERENCES users (id),     -- NULL only when the user is unknown (for example a failed login)
  device_id   uuid REFERENCES devices (id),
  action      text NOT NULL CHECK (action IN ('create', 'edit', 'delete', 'referral', 'alert', 'login', 'sync_conflict')),
  entity_type text,                            -- table name of the affected row
  entity_id   uuid,
  details     jsonb NOT NULL DEFAULT '{}'
);

-- The audit log viewer filters by user, action and date (roadmap, Module 10 base).
CREATE INDEX audit_log_occurred_at_idx ON audit_log (occurred_at);
CREATE INDEX audit_log_user_id_idx ON audit_log (user_id, occurred_at);
CREATE INDEX audit_log_action_idx ON audit_log (action, occurred_at);

CREATE FUNCTION prevent_audit_log_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'audit_log is append-only' USING ERRCODE = 'restrict_violation';
END;
$$;

CREATE TRIGGER audit_log_append_only BEFORE UPDATE OR DELETE ON audit_log
  FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_change();

-- Supervisor review queue for conflicting offline submissions (M3 FE-2, LI-7).
-- A different record for the same woman on the same day lands here instead of
-- overwriting the existing one.
CREATE TABLE sync_conflicts (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  area_id            uuid NOT NULL REFERENCES areas (id),
  table_name         text NOT NULL,
  incoming_record_id uuid NOT NULL,
  existing_record_id uuid,
  incoming_payload   jsonb NOT NULL,
  reason             text NOT NULL,
  submitted_by       uuid REFERENCES users (id),
  device_id          uuid REFERENCES devices (id),
  status             text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'resolved')),
  resolution         text,
  resolved_by        uuid REFERENCES users (id),
  resolved_at        timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX sync_conflicts_area_status_idx ON sync_conflicts (area_id, status);

-- Weekly and monthly PDF and Excel reports (M10 FE-2).
CREATE TABLE report_jobs (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_type  text NOT NULL,
  period       text NOT NULL CHECK (period IN ('weekly', 'monthly')),
  format       text NOT NULL CHECK (format IN ('pdf', 'xlsx')),
  filters      jsonb NOT NULL DEFAULT '{}',
  status       text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'done', 'failed')),
  requested_by uuid REFERENCES users (id),    -- NULL for scheduled reports
  output_path  text,
  error        text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  started_at   timestamptz,
  finished_at  timestamptz
);

-- Down Migration

DROP TABLE report_jobs;
DROP TABLE sync_conflicts;
DROP TABLE audit_log;
DROP FUNCTION prevent_audit_log_change();
