-- Up Migration

-- Visits (Phase 1; used by M3, M4, M6): one row per home visit with all vitals and
-- symptoms (M3 FE-1). Synced table.
--
-- Units are fixed by the column name and never converted in storage:
-- BP in mmHg, temperature in °C, blood sugar in mmol/L, weight in kg, pulse in beats/min.
-- Out-of-range values are confirmed in the app (for example systolic outside 60–250),
-- so the database only rejects impossible values.
CREATE TABLE visits (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq          bigint NOT NULL,
  area_id             uuid NOT NULL REFERENCES areas (id),
  created_by          uuid NOT NULL REFERENCES users (id),
  created_on_device   timestamptz,
  synced_at           timestamptz NOT NULL,
  deleted_at          timestamptz,
  pregnancy_id        uuid NOT NULL REFERENCES pregnancies (id),
  visited_at          timestamptz NOT NULL,       -- device clock: display only, never for ordering (LI-7)
  systolic_bp_mmhg    smallint CHECK (systolic_bp_mmhg > 0),
  diastolic_bp_mmhg   smallint CHECK (diastolic_bp_mmhg > 0),
  weight_kg           numeric(5, 2) CHECK (weight_kg > 0),
  temperature_c       numeric(4, 1) CHECK (temperature_c > 0),
  pulse_bpm           smallint CHECK (pulse_bpm > 0),          -- added for the M4 model (roadmap Risks)
  blood_sugar_mmol_l  numeric(4, 1) CHECK (blood_sugar_mmol_l > 0), -- optional (roadmap Risks)
  fetal_movement      text CHECK (fetal_movement IN ('normal', 'reduced', 'absent')),
  swelling            boolean NOT NULL DEFAULT false,
  bleeding            boolean NOT NULL DEFAULT false,
  fever               boolean NOT NULL DEFAULT false,
  anaemia_signs       text NOT NULL DEFAULT 'none' CHECK (anaemia_signs IN ('none', 'present', 'severe')),
  urine_symptoms      boolean NOT NULL DEFAULT false
);

CREATE INDEX visits_pregnancy_id_idx ON visits (pregnancy_id);

CREATE TRIGGER visits_server_seq BEFORE INSERT OR UPDATE ON visits FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER visits_no_hard_delete BEFORE DELETE ON visits FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE UNIQUE INDEX visits_server_seq_key ON visits (server_seq);
CREATE INDEX visits_area_seq_idx ON visits (area_id, server_seq);

-- Down Migration

DROP TABLE visits;
