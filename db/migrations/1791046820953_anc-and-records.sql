-- Up Migration

-- ANC and records (Phase 2; used by M6): ANC schedule, TT doses, supplement logs,
-- scanned health documents and trend results. Synced tables.

-- Personalised ANC visit schedule from gestational age at registration (M6 FE-1).
CREATE TABLE anc_schedule (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq         bigint NOT NULL,
  area_id            uuid NOT NULL REFERENCES areas (id),
  created_by         uuid NOT NULL REFERENCES users (id),
  created_on_device  timestamptz,
  synced_at          timestamptz NOT NULL,
  deleted_at         timestamptz,
  pregnancy_id       uuid NOT NULL REFERENCES pregnancies (id),
  visit_number       smallint NOT NULL CHECK (visit_number > 0),
  due_on             date NOT NULL,
  completed_visit_id uuid REFERENCES visits (id)
);

CREATE UNIQUE INDEX anc_schedule_visit_key ON anc_schedule (pregnancy_id, visit_number) WHERE deleted_at IS NULL;

-- TT vaccination doses on the pregnancy timeline (M6 FE-1).
CREATE TABLE tt_doses (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  pregnancy_id      uuid NOT NULL REFERENCES pregnancies (id),
  dose_number       smallint NOT NULL CHECK (dose_number > 0),
  due_on            date,
  given_on          date
);

CREATE UNIQUE INDEX tt_doses_dose_key ON tt_doses (pregnancy_id, dose_number) WHERE deleted_at IS NULL;

-- Iron and folic acid compliance entries (M6 FE-1).
CREATE TABLE supplement_logs (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  pregnancy_id      uuid NOT NULL REFERENCES pregnancies (id),
  supplement        text NOT NULL CHECK (supplement IN ('iron', 'folic_acid')),
  log_date          date NOT NULL,
  taken             boolean NOT NULL
);

-- Scanned hospital reports (M6 FE-2). The image uploads after the data rows, so
-- image_path stays NULL until the upload completes. Every scan needs LHW
-- confirmation (LI-9).
CREATE TABLE health_documents (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  woman_id          uuid NOT NULL REFERENCES women (id),
  pregnancy_id      uuid REFERENCES pregnancies (id),
  captured_at       timestamptz NOT NULL,
  image_path        text,
  extracted_values  jsonb NOT NULL DEFAULT '{}',
  confidence        jsonb NOT NULL DEFAULT '{}',
  verified_at       timestamptz
);

-- Output of the Python analytics worker (M6 FE-3): slope per vital, Z-score
-- anomalies and weighted compliance score, returned to the device on next sync.
-- created_by is NULL because the server generates these rows.
CREATE TABLE trend_results (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  pregnancy_id      uuid NOT NULL REFERENCES pregnancies (id),
  computed_at       timestamptz NOT NULL DEFAULT now(),
  vital_slopes      jsonb NOT NULL DEFAULT '{}',
  anomalies         jsonb NOT NULL DEFAULT '[]',
  compliance_score  numeric(5, 2) CHECK (compliance_score BETWEEN 0 AND 100)
);

CREATE INDEX supplement_logs_pregnancy_id_idx ON supplement_logs (pregnancy_id);
CREATE INDEX health_documents_woman_id_idx ON health_documents (woman_id);
CREATE INDEX trend_results_pregnancy_id_idx ON trend_results (pregnancy_id);

CREATE TRIGGER anc_schedule_server_seq BEFORE INSERT OR UPDATE ON anc_schedule FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER tt_doses_server_seq BEFORE INSERT OR UPDATE ON tt_doses FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER supplement_logs_server_seq BEFORE INSERT OR UPDATE ON supplement_logs FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER health_documents_server_seq BEFORE INSERT OR UPDATE ON health_documents FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER trend_results_server_seq BEFORE INSERT OR UPDATE ON trend_results FOR EACH ROW EXECUTE FUNCTION assign_server_seq();

CREATE TRIGGER anc_schedule_no_hard_delete BEFORE DELETE ON anc_schedule FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER tt_doses_no_hard_delete BEFORE DELETE ON tt_doses FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER supplement_logs_no_hard_delete BEFORE DELETE ON supplement_logs FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER health_documents_no_hard_delete BEFORE DELETE ON health_documents FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER trend_results_no_hard_delete BEFORE DELETE ON trend_results FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();

CREATE UNIQUE INDEX anc_schedule_server_seq_key ON anc_schedule (server_seq);
CREATE UNIQUE INDEX tt_doses_server_seq_key ON tt_doses (server_seq);
CREATE UNIQUE INDEX supplement_logs_server_seq_key ON supplement_logs (server_seq);
CREATE UNIQUE INDEX health_documents_server_seq_key ON health_documents (server_seq);
CREATE UNIQUE INDEX trend_results_server_seq_key ON trend_results (server_seq);

CREATE INDEX anc_schedule_area_seq_idx ON anc_schedule (area_id, server_seq);
CREATE INDEX tt_doses_area_seq_idx ON tt_doses (area_id, server_seq);
CREATE INDEX supplement_logs_area_seq_idx ON supplement_logs (area_id, server_seq);
CREATE INDEX health_documents_area_seq_idx ON health_documents (area_id, server_seq);
CREATE INDEX trend_results_area_seq_idx ON trend_results (area_id, server_seq);

-- Down Migration

DROP TABLE trend_results;
DROP TABLE health_documents;
DROP TABLE supplement_logs;
DROP TABLE tt_doses;
DROP TABLE anc_schedule;
