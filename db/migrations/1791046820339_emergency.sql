-- Up Migration

-- Emergency (Phase 2; used by M5, M10): referrals, emergency alerts, every alert
-- attempt per channel, and acknowledgements. Synced tables.

-- One-tap referral for Red-risk patients and its outcome (M5 FE-1, FE-3).
CREATE TABLE referrals (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq          bigint NOT NULL,
  area_id             uuid NOT NULL REFERENCES areas (id),
  created_by          uuid NOT NULL REFERENCES users (id),
  created_on_device   timestamptz,
  synced_at           timestamptz NOT NULL,
  deleted_at          timestamptz,
  pregnancy_id        uuid NOT NULL REFERENCES pregnancies (id),
  visit_id            uuid REFERENCES visits (id),
  risk_assessment_id  uuid REFERENCES risk_assessments (id),
  hospital_id         uuid REFERENCES hospitals (id),
  risk_factors        jsonb NOT NULL DEFAULT '[]',
  referred_at         timestamptz NOT NULL,
  attended            boolean,                 -- outcome: did the patient reach the hospital
  outcome             text,
  outcome_recorded_at timestamptz
);

-- Emergency alert raised for a Red-risk or Emergency patient (M5 FE-2, FE-4, FE-5).
-- visit_recorded_at and escalation_seconds let supervisors see any delay (M5 FE-4 e).
CREATE TABLE emergency_alerts (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq         bigint NOT NULL,
  area_id            uuid NOT NULL REFERENCES areas (id),
  created_by         uuid NOT NULL REFERENCES users (id),
  created_on_device  timestamptz,
  synced_at          timestamptz NOT NULL,
  deleted_at         timestamptz,
  pregnancy_id       uuid NOT NULL REFERENCES pregnancies (id),
  visit_id           uuid REFERENCES visits (id),
  risk_assessment_id uuid REFERENCES risk_assessments (id),
  referral_id        uuid REFERENCES referrals (id),
  visit_recorded_at  timestamptz NOT NULL,
  raised_at          timestamptz NOT NULL,
  escalation_seconds integer CHECK (escalation_seconds >= 0),
  status             text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'acknowledged', 'escalated')),
  escalated_at       timestamptz
);

-- Every attempt on each of the three independent options (M5 FE-2, FE-4 d).
CREATE TABLE alert_attempts (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  alert_id          uuid NOT NULL REFERENCES emergency_alerts (id),
  channel           text NOT NULL CHECK (channel IN ('internet', 'sms', 'call')),
  recipient         text CHECK (recipient IN ('supervisor', 'secondary')),
  status            text NOT NULL CHECK (status IN ('sent', 'delivered', 'failed', 'not_available')),
  attempted_at      timestamptz NOT NULL
);

-- Acknowledgement by the supervisor (dashboard or app) or "supervisor reached"
-- marked by the LHW after a call or SMS reply (M5 FE-5).
CREATE TABLE alert_acknowledgements (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  alert_id          uuid NOT NULL REFERENCES emergency_alerts (id),
  method            text NOT NULL CHECK (method IN ('dashboard', 'app', 'supervisor_reached')),
  acknowledged_at   timestamptz NOT NULL
);

CREATE INDEX referrals_pregnancy_id_idx ON referrals (pregnancy_id);
CREATE INDEX emergency_alerts_pregnancy_id_idx ON emergency_alerts (pregnancy_id);
CREATE INDEX emergency_alerts_status_idx ON emergency_alerts (area_id, status);
CREATE INDEX alert_attempts_alert_id_idx ON alert_attempts (alert_id);
CREATE INDEX alert_acknowledgements_alert_id_idx ON alert_acknowledgements (alert_id);

CREATE TRIGGER referrals_server_seq BEFORE INSERT OR UPDATE ON referrals FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER emergency_alerts_server_seq BEFORE INSERT OR UPDATE ON emergency_alerts FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER alert_attempts_server_seq BEFORE INSERT OR UPDATE ON alert_attempts FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER alert_acknowledgements_server_seq BEFORE INSERT OR UPDATE ON alert_acknowledgements FOR EACH ROW EXECUTE FUNCTION assign_server_seq();

CREATE TRIGGER referrals_no_hard_delete BEFORE DELETE ON referrals FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER emergency_alerts_no_hard_delete BEFORE DELETE ON emergency_alerts FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER alert_attempts_no_hard_delete BEFORE DELETE ON alert_attempts FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER alert_acknowledgements_no_hard_delete BEFORE DELETE ON alert_acknowledgements FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();

CREATE UNIQUE INDEX referrals_server_seq_key ON referrals (server_seq);
CREATE UNIQUE INDEX emergency_alerts_server_seq_key ON emergency_alerts (server_seq);
CREATE UNIQUE INDEX alert_attempts_server_seq_key ON alert_attempts (server_seq);
CREATE UNIQUE INDEX alert_acknowledgements_server_seq_key ON alert_acknowledgements (server_seq);

CREATE INDEX referrals_area_seq_idx ON referrals (area_id, server_seq);
CREATE INDEX emergency_alerts_area_seq_idx ON emergency_alerts (area_id, server_seq);
CREATE INDEX alert_attempts_area_seq_idx ON alert_attempts (area_id, server_seq);
CREATE INDEX alert_acknowledgements_area_seq_idx ON alert_acknowledgements (area_id, server_seq);

-- Down Migration

DROP TABLE alert_acknowledgements;
DROP TABLE alert_attempts;
DROP TABLE emergency_alerts;
DROP TABLE referrals;
