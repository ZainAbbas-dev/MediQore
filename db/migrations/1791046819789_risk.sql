-- Up Migration

-- Risk (Phase 2; used by M4, M10): one assessment per visit, computed on the device
-- right after the visit form is submitted. Synced table.
--
-- final_level is always the higher of the model result and the danger-sign rules
-- (M4 FE-4). model_version and rules_version keep every result traceable when the
-- model or the clinical rules config changes (LI-2).
CREATE TABLE risk_assessments (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq          bigint NOT NULL,
  area_id             uuid NOT NULL REFERENCES areas (id),
  created_by          uuid NOT NULL REFERENCES users (id),
  created_on_device   timestamptz,
  synced_at           timestamptz NOT NULL,
  deleted_at          timestamptz,
  visit_id            uuid NOT NULL REFERENCES visits (id),
  pregnancy_id        uuid NOT NULL REFERENCES pregnancies (id),
  model_level         text NOT NULL CHECK (model_level IN ('low', 'mid', 'high')),
  model_probabilities jsonb,
  model_version       text NOT NULL,
  rule_result         text NOT NULL CHECK (rule_result IN ('none', 'emergency')),
  triggered_rules     jsonb NOT NULL DEFAULT '[]',
  rules_version       text NOT NULL,
  final_level         text NOT NULL CHECK (final_level IN ('green', 'yellow', 'red')),
  is_emergency        boolean NOT NULL DEFAULT false,
  explanation_key     text,                    -- key into the SHAP Urdu lookup (M4 FE-2)
  CHECK (NOT is_emergency OR final_level = 'red')
);

CREATE UNIQUE INDEX risk_assessments_one_per_visit ON risk_assessments (visit_id) WHERE deleted_at IS NULL;
CREATE INDEX risk_assessments_pregnancy_id_idx ON risk_assessments (pregnancy_id);

CREATE TRIGGER risk_assessments_server_seq BEFORE INSERT OR UPDATE ON risk_assessments FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER risk_assessments_no_hard_delete BEFORE DELETE ON risk_assessments FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE UNIQUE INDEX risk_assessments_server_seq_key ON risk_assessments (server_seq);
CREATE INDEX risk_assessments_area_seq_idx ON risk_assessments (area_id, server_seq);

-- Down Migration

DROP TABLE risk_assessments;
