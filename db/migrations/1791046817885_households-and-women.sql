-- Up Migration

-- Households and women (Phase 1; used by M2, M7). Synced tables: base columns
-- and triggers as described in the sync-foundation migration.

-- Household with GPS (M2 FE-3), reused later by the polio and child modules.
-- The registration form's address and village are stored here.
CREATE TABLE households (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  household_number  text,
  address           text,
  village           text,
  latitude          numeric(9, 6) CHECK (latitude BETWEEN -90 AND 90),
  longitude         numeric(9, 6) CHECK (longitude BETWEEN -180 AND 180),
  CHECK ((latitude IS NULL) = (longitude IS NULL))
);

-- Registered woman (M2 FE-1). patient_code = LHW code + local counter, unique offline.
CREATE TABLE women (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  household_id      uuid NOT NULL REFERENCES households (id),
  patient_code      text NOT NULL UNIQUE,
  name              text NOT NULL,
  age               smallint CHECK (age > 0),
  husband_name      text,
  contact_number    text
);

-- Pregnancy file (M2 FE-1): one woman can have several pregnancies over time,
-- but only one active at a time.
CREATE TABLE pregnancies (
  id                              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq                      bigint NOT NULL,
  area_id                         uuid NOT NULL REFERENCES areas (id),
  created_by                      uuid NOT NULL REFERENCES users (id),
  created_on_device               timestamptz,
  synced_at                       timestamptz NOT NULL,
  deleted_at                      timestamptz,
  woman_id                        uuid NOT NULL REFERENCES women (id),
  registered_on                   date NOT NULL,
  pregnancy_month_at_registration smallint NOT NULL CHECK (pregnancy_month_at_registration BETWEEN 1 AND 10),
  status                          text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'closed')),
  closed_on                       date
);

CREATE UNIQUE INDEX pregnancies_one_active_per_woman ON pregnancies (woman_id)
  WHERE status = 'active' AND deleted_at IS NULL;

-- Obstetric history captured at registration: the baseline risk profile (M2 FE-2).
CREATE TABLE obstetric_history (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq           bigint NOT NULL,
  area_id              uuid NOT NULL REFERENCES areas (id),
  created_by           uuid NOT NULL REFERENCES users (id),
  created_on_device    timestamptz,
  synced_at            timestamptz NOT NULL,
  deleted_at           timestamptz,
  woman_id             uuid NOT NULL REFERENCES women (id),
  previous_pregnancies smallint NOT NULL DEFAULT 0 CHECK (previous_pregnancies >= 0),
  previous_c_sections  smallint NOT NULL DEFAULT 0 CHECK (previous_c_sections >= 0),
  stillbirths          smallint NOT NULL DEFAULT 0 CHECK (stillbirths >= 0),
  known_conditions     text
);

CREATE UNIQUE INDEX obstetric_history_one_per_woman ON obstetric_history (woman_id) WHERE deleted_at IS NULL;

CREATE INDEX women_household_id_idx ON women (household_id);
CREATE INDEX pregnancies_woman_id_idx ON pregnancies (woman_id);

CREATE TRIGGER households_server_seq BEFORE INSERT OR UPDATE ON households FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER women_server_seq BEFORE INSERT OR UPDATE ON women FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER pregnancies_server_seq BEFORE INSERT OR UPDATE ON pregnancies FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER obstetric_history_server_seq BEFORE INSERT OR UPDATE ON obstetric_history FOR EACH ROW EXECUTE FUNCTION assign_server_seq();

CREATE TRIGGER households_no_hard_delete BEFORE DELETE ON households FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER women_no_hard_delete BEFORE DELETE ON women FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER pregnancies_no_hard_delete BEFORE DELETE ON pregnancies FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER obstetric_history_no_hard_delete BEFORE DELETE ON obstetric_history FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();

CREATE UNIQUE INDEX households_server_seq_key ON households (server_seq);
CREATE UNIQUE INDEX women_server_seq_key ON women (server_seq);
CREATE UNIQUE INDEX pregnancies_server_seq_key ON pregnancies (server_seq);
CREATE UNIQUE INDEX obstetric_history_server_seq_key ON obstetric_history (server_seq);

CREATE INDEX households_area_seq_idx ON households (area_id, server_seq);
CREATE INDEX women_area_seq_idx ON women (area_id, server_seq);
CREATE INDEX pregnancies_area_seq_idx ON pregnancies (area_id, server_seq);
CREATE INDEX obstetric_history_area_seq_idx ON obstetric_history (area_id, server_seq);

-- Down Migration

DROP TABLE obstetric_history;
DROP TABLE pregnancies;
DROP TABLE women;
DROP TABLE households;
