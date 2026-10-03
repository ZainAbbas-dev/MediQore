-- Up Migration

-- Immunisation (Phase 3; used by M8).

-- Server copy of the versioned EPI schedule config (BCG, OPV-0, Penta 1–3, PCV 1–3,
-- Rota 1–2, IPV, MR), loaded from the JSON config file for coverage reports
-- (M8 FE-1, FE-3). The JSON file stays the source of truth; due ages come from the
-- official Pakistan EPI schedule. Server-only.
CREATE TABLE epi_schedule (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  config_version text NOT NULL,
  antigen        text NOT NULL,
  due_age_days   integer NOT NULL CHECK (due_age_days >= 0),
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (config_version, antigen)
);

-- Dose given to a child (M8 FE-1). Birth-dose OPV-0 is recorded here; campaign
-- OPV doses belong to Module 7.
CREATE TABLE immunisations (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  child_id          uuid NOT NULL REFERENCES children (id),
  antigen           text NOT NULL,
  given_on          date NOT NULL
);

CREATE UNIQUE INDEX immunisations_dose_key ON immunisations (child_id, antigen) WHERE deleted_at IS NULL;

CREATE TRIGGER immunisations_server_seq BEFORE INSERT OR UPDATE ON immunisations FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER immunisations_no_hard_delete BEFORE DELETE ON immunisations FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE UNIQUE INDEX immunisations_server_seq_key ON immunisations (server_seq);
CREATE INDEX immunisations_area_seq_idx ON immunisations (area_id, server_seq);

-- Down Migration

DROP TABLE immunisations;
DROP TABLE epi_schedule;
