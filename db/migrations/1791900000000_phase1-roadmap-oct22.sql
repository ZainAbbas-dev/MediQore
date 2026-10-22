-- Up Migration

-- Phase 1 brought up to the updated scope and the roadmap of 22 Oct 2026.

-- ---------------------------------------------------------------------------
-- Record versions (M3 FE-2, roadmap "Record IDs"): every synced table carries a
-- version number that starts at 1 and rises with each accepted change. A device
-- sends the version its edit was based on; an older base version is a conflict.
-- The synced tables are the ones with a server_seq column.
-- ---------------------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOR t IN
    SELECT table_name FROM information_schema.columns
    WHERE table_schema = current_schema() AND column_name = 'server_seq'
  LOOP
    EXECUTE format('ALTER TABLE %I ADD COLUMN version integer NOT NULL DEFAULT 1 CHECK (version >= 1)', t);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION assign_server_seq() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('mediqore.sync_server_seq'));
  NEW.server_seq := nextval('sync_server_seq');
  NEW.synced_at := now();
  NEW.version := CASE WHEN TG_OP = 'UPDATE' THEN OLD.version + 1 ELSE 1 END;
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- Activation number (M2 FE-1): issued by the server at each device activation,
-- so the Patient ID [LHW code]-[activation number]-[sequence number] made on
-- the phone is unique before the first sync. Numbered per account from 1.
-- ---------------------------------------------------------------------------
ALTER TABLE devices ADD COLUMN activation_number integer CHECK (activation_number >= 1);

UPDATE devices d SET activation_number = n.rn
FROM (
  SELECT id, row_number() OVER (PARTITION BY user_id ORDER BY activated_at, id) AS rn
  FROM devices WHERE activated_at IS NOT NULL
) n
WHERE d.id = n.id;

CREATE UNIQUE INDEX devices_user_activation_number_key ON devices (user_id, activation_number);
ALTER TABLE devices ADD CONSTRAINT devices_activated_have_number
  CHECK ((activated_at IS NULL) OR (activation_number IS NOT NULL));

-- ---------------------------------------------------------------------------
-- Estimated delivery date (M2 FE-1): from the LMP date or a known EDD,
-- otherwise from the pregnancy month (Clinical Rules Table, gestational_age).
-- Gestational age on any date is calculated from it.
-- ---------------------------------------------------------------------------
ALTER TABLE pregnancies ADD COLUMN lmp_date date;
ALTER TABLE pregnancies ADD COLUMN reported_edd date;
ALTER TABLE pregnancies ADD COLUMN estimated_delivery_date date;
ALTER TABLE pregnancies ADD COLUMN edd_basis text CHECK (edd_basis IN ('lmp', 'edd', 'month'));

-- Earlier pregnancies knew only the month: the month's midpoint, 4.345 weeks a month, 40 weeks at term.
UPDATE pregnancies
SET estimated_delivery_date = registered_on + round((40 - (pregnancy_month_at_registration - 0.5) * 4.345) * 7)::integer,
    edd_basis = 'month';

ALTER TABLE pregnancies ALTER COLUMN estimated_delivery_date SET NOT NULL;
ALTER TABLE pregnancies ALTER COLUMN edd_basis SET NOT NULL;
ALTER TABLE pregnancies ADD CONSTRAINT pregnancies_edd_basis_date CHECK (
  (edd_basis = 'lmp') = (lmp_date IS NOT NULL) AND (edd_basis = 'edd') = (reported_edd IS NOT NULL)
);

-- ---------------------------------------------------------------------------
-- Blood sugar is stored with the unit it was recorded in (M3 FE-1), so a
-- mg/dL reading keeps its exact value. It is converted only for the ranges and
-- the model (M4 FE-1).
-- ---------------------------------------------------------------------------
ALTER TABLE visits DROP CONSTRAINT visits_blood_sugar_details_need_value;
ALTER TABLE visits RENAME COLUMN blood_sugar_entered_unit TO blood_sugar_unit;
ALTER TABLE visits ADD COLUMN blood_sugar_value numeric(5, 1) CHECK (blood_sugar_value > 0);

UPDATE visits
SET blood_sugar_unit = coalesce(blood_sugar_unit, 'mmol_l'),
    blood_sugar_value = CASE WHEN blood_sugar_unit = 'mg_dl' THEN round(blood_sugar_mmol_l * 18) ELSE blood_sugar_mmol_l END
WHERE blood_sugar_mmol_l IS NOT NULL;

ALTER TABLE visits DROP COLUMN blood_sugar_mmol_l;
ALTER TABLE visits ADD CONSTRAINT visits_blood_sugar_value_unit CHECK ((blood_sugar_value IS NULL) = (blood_sugar_unit IS NULL));
ALTER TABLE visits ADD CONSTRAINT visits_blood_sugar_details_need_value CHECK (
  blood_sugar_value IS NOT NULL OR (blood_sugar_measured_on IS NULL AND blood_sugar_source IS NULL)
);

-- ---------------------------------------------------------------------------
-- Conflict Review (M3 FE-2, M10 FE-3): an edit made on an older version than the
-- server's ('outdated_edit', not applied) and a likely duplicate patient
-- ('possible_duplicate', stored and listed). Earlier same-day holds keep their reason.
-- ---------------------------------------------------------------------------
ALTER TABLE sync_conflicts ADD COLUMN base_version integer;
ALTER TABLE sync_conflicts ADD COLUMN existing_version integer;
ALTER TABLE sync_conflicts ADD CONSTRAINT sync_conflicts_reason_check
  CHECK (reason IN ('same_parent_same_day', 'outdated_edit', 'possible_duplicate'));
CREATE UNIQUE INDEX sync_conflicts_one_pending_per_record
  ON sync_conflicts (table_name, incoming_record_id, reason) WHERE status = 'pending';

-- Duplicate check: women of an area by household and name.
CREATE INDEX women_area_household_idx ON women (area_id, household_id) WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- Role permissions managed by the admin (M10 FE-3, M1 FE-2). The API keeps the
-- default for each role and permission; a row here records the admin's choice.
-- ---------------------------------------------------------------------------
CREATE TABLE role_permissions (
  role        text NOT NULL CHECK (role IN ('lhw', 'supervisor', 'admin')),
  permission  text NOT NULL,
  granted     boolean NOT NULL,
  updated_by  uuid NOT NULL REFERENCES users (id),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role, permission)
);

-- Down Migration

DROP TABLE role_permissions;

DROP INDEX women_area_household_idx;
DROP INDEX sync_conflicts_one_pending_per_record;
ALTER TABLE sync_conflicts DROP CONSTRAINT sync_conflicts_reason_check;
ALTER TABLE sync_conflicts DROP COLUMN existing_version;
ALTER TABLE sync_conflicts DROP COLUMN base_version;

ALTER TABLE visits DROP CONSTRAINT visits_blood_sugar_details_need_value;
ALTER TABLE visits DROP CONSTRAINT visits_blood_sugar_value_unit;
ALTER TABLE visits ADD COLUMN blood_sugar_mmol_l numeric(4, 1) CHECK (blood_sugar_mmol_l > 0);
UPDATE visits
SET blood_sugar_mmol_l = CASE WHEN blood_sugar_unit = 'mg_dl' THEN round(blood_sugar_value / 18, 1) ELSE blood_sugar_value END
WHERE blood_sugar_value IS NOT NULL;
ALTER TABLE visits DROP COLUMN blood_sugar_value;
ALTER TABLE visits RENAME COLUMN blood_sugar_unit TO blood_sugar_entered_unit;
ALTER TABLE visits ADD CONSTRAINT visits_blood_sugar_details_need_value CHECK (
  blood_sugar_mmol_l IS NOT NULL
  OR (blood_sugar_entered_unit IS NULL AND blood_sugar_measured_on IS NULL AND blood_sugar_source IS NULL)
);

ALTER TABLE pregnancies DROP CONSTRAINT pregnancies_edd_basis_date;
ALTER TABLE pregnancies DROP COLUMN edd_basis;
ALTER TABLE pregnancies DROP COLUMN estimated_delivery_date;
ALTER TABLE pregnancies DROP COLUMN reported_edd;
ALTER TABLE pregnancies DROP COLUMN lmp_date;

ALTER TABLE devices DROP CONSTRAINT devices_activated_have_number;
DROP INDEX devices_user_activation_number_key;
ALTER TABLE devices DROP COLUMN activation_number;

CREATE OR REPLACE FUNCTION assign_server_seq() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('mediqore.sync_server_seq'));
  NEW.server_seq := nextval('sync_server_seq');
  NEW.synced_at := now();
  RETURN NEW;
END;
$$;

DO $$
DECLARE t text;
BEGIN
  FOR t IN
    SELECT table_name FROM information_schema.columns
    WHERE table_schema = current_schema() AND column_name = 'server_seq'
  LOOP
    EXECUTE format('ALTER TABLE %I DROP COLUMN version', t);
  END LOOP;
END;
$$;
