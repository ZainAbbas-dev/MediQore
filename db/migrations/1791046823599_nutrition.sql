-- Up Migration

-- Nutrition (Phase 3; used by M9): MUAC and Z-score screenings, SAM follow-ups and
-- IMCI assessments. Synced tables. MUAC is stored in mm, weight in kg, height in cm.

-- MUAC with WHO classification and growth Z-scores (M9 FE-1).
CREATE TABLE nutrition_screenings (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  child_id          uuid NOT NULL REFERENCES children (id),
  screened_on       date NOT NULL,
  muac_mm           smallint CHECK (muac_mm > 0),
  muac_class        text CHECK (muac_class IN ('sam', 'mam', 'normal')),
  weight_kg         numeric(5, 2) CHECK (weight_kg > 0),
  height_cm         numeric(5, 1) CHECK (height_cm > 0),
  weight_for_age_z  numeric(4, 2),
  height_for_age_z  numeric(4, 2),
  underweight       boolean,
  stunting          boolean,
  wasting           boolean,
  rules_version     text NOT NULL            -- version of the MUAC / Z-score config used
);

-- SAM referral to a Nutrition Rehabilitation Centre and follow-up visits (M9 FE-2).
CREATE TABLE sam_followups (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq         bigint NOT NULL,
  area_id            uuid NOT NULL REFERENCES areas (id),
  created_by         uuid NOT NULL REFERENCES users (id),
  created_on_device  timestamptz,
  synced_at          timestamptz NOT NULL,
  deleted_at         timestamptz,
  child_id           uuid NOT NULL REFERENCES children (id),
  screening_id       uuid REFERENCES nutrition_screenings (id),
  referral_centre_id uuid REFERENCES referral_centres (id),
  followup_on        date NOT NULL,
  attended           boolean,
  weight_kg          numeric(5, 2) CHECK (weight_kg > 0)
);

-- IMCI diarrhoea and pneumonia assessment (M9 FE-3).
CREATE TABLE imci_assessments (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  child_id          uuid NOT NULL REFERENCES children (id),
  assessed_on       date NOT NULL,
  respiratory_rate  smallint CHECK (respiratory_rate > 0),   -- breaths per minute
  chest_indrawing   boolean,
  stool_frequency   smallint CHECK (stool_frequency >= 0),   -- stools per day
  dehydration_signs jsonb NOT NULL DEFAULT '[]',
  classification    text,
  severity          text,
  action_key        text,                                    -- key of the Urdu action text in the IMCI config
  rules_version     text NOT NULL
);

CREATE INDEX nutrition_screenings_child_id_idx ON nutrition_screenings (child_id);
CREATE INDEX sam_followups_child_id_idx ON sam_followups (child_id);
CREATE INDEX imci_assessments_child_id_idx ON imci_assessments (child_id);

CREATE TRIGGER nutrition_screenings_server_seq BEFORE INSERT OR UPDATE ON nutrition_screenings FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER sam_followups_server_seq BEFORE INSERT OR UPDATE ON sam_followups FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER imci_assessments_server_seq BEFORE INSERT OR UPDATE ON imci_assessments FOR EACH ROW EXECUTE FUNCTION assign_server_seq();

CREATE TRIGGER nutrition_screenings_no_hard_delete BEFORE DELETE ON nutrition_screenings FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER sam_followups_no_hard_delete BEFORE DELETE ON sam_followups FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER imci_assessments_no_hard_delete BEFORE DELETE ON imci_assessments FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();

CREATE UNIQUE INDEX nutrition_screenings_server_seq_key ON nutrition_screenings (server_seq);
CREATE UNIQUE INDEX sam_followups_server_seq_key ON sam_followups (server_seq);
CREATE UNIQUE INDEX imci_assessments_server_seq_key ON imci_assessments (server_seq);

CREATE INDEX nutrition_screenings_area_seq_idx ON nutrition_screenings (area_id, server_seq);
CREATE INDEX sam_followups_area_seq_idx ON sam_followups (area_id, server_seq);
CREATE INDEX imci_assessments_area_seq_idx ON imci_assessments (area_id, server_seq);

-- Down Migration

DROP TABLE imci_assessments;
DROP TABLE sam_followups;
DROP TABLE nutrition_screenings;
