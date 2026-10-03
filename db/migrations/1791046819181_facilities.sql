-- Up Migration

-- Facilities (Phase 1–2; used by M5, M9, M10). Created by admins on the portal
-- (M10 FE-3) and pulled to devices, so they carry the sync base columns.
-- Hospitals and referral centres serve a whole district, so area_id is optional
-- there and district_id is required; created_on_device stays NULL for web-created rows.

-- Referral hospitals including District Headquarters Hospitals (M5 FE-1).
-- Coordinates let the app find the nearest one offline.
CREATE TABLE hospitals (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  district_id       uuid NOT NULL REFERENCES districts (id),
  name              text NOT NULL,
  facility_type     text,
  address           text,
  phone             text,
  latitude          numeric(9, 6) CHECK (latitude BETWEEN -90 AND 90),
  longitude         numeric(9, 6) CHECK (longitude BETWEEN -180 AND 180),
  CHECK ((latitude IS NULL) = (longitude IS NULL))
);

-- Other referral destinations, for example Nutrition Rehabilitation Centres (M9 FE-2, Phase 3).
CREATE TABLE referral_centres (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  district_id       uuid NOT NULL REFERENCES districts (id),
  name              text NOT NULL,
  centre_type       text NOT NULL,
  address           text,
  phone             text,
  latitude          numeric(9, 6) CHECK (latitude BETWEEN -90 AND 90),
  longitude         numeric(9, 6) CHECK (longitude BETWEEN -180 AND 180),
  CHECK ((latitude IS NULL) = (longitude IS NULL))
);

-- Emergency escalation contacts per area: supervisor and secondary contact (M10 FE-3).
-- An unacknowledged alert escalates after escalate_after_minutes (M5 FE-5, default 15).
CREATE TABLE escalation_contacts (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq             bigint NOT NULL,
  area_id                uuid NOT NULL REFERENCES areas (id),
  created_by             uuid NOT NULL REFERENCES users (id),
  created_on_device      timestamptz,
  synced_at              timestamptz NOT NULL,
  deleted_at             timestamptz,
  supervisor_user_id     uuid REFERENCES users (id),
  supervisor_phone       text NOT NULL,
  secondary_name         text,
  secondary_phone        text,
  escalate_after_minutes smallint NOT NULL DEFAULT 15 CHECK (escalate_after_minutes > 0)
);

CREATE UNIQUE INDEX escalation_contacts_one_per_area ON escalation_contacts (area_id) WHERE deleted_at IS NULL;
CREATE INDEX hospitals_district_seq_idx ON hospitals (district_id, server_seq);
CREATE INDEX referral_centres_district_seq_idx ON referral_centres (district_id, server_seq);

CREATE TRIGGER hospitals_server_seq BEFORE INSERT OR UPDATE ON hospitals FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER referral_centres_server_seq BEFORE INSERT OR UPDATE ON referral_centres FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER escalation_contacts_server_seq BEFORE INSERT OR UPDATE ON escalation_contacts FOR EACH ROW EXECUTE FUNCTION assign_server_seq();

CREATE TRIGGER hospitals_no_hard_delete BEFORE DELETE ON hospitals FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER referral_centres_no_hard_delete BEFORE DELETE ON referral_centres FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER escalation_contacts_no_hard_delete BEFORE DELETE ON escalation_contacts FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();

CREATE UNIQUE INDEX hospitals_server_seq_key ON hospitals (server_seq);
CREATE UNIQUE INDEX referral_centres_server_seq_key ON referral_centres (server_seq);
CREATE UNIQUE INDEX escalation_contacts_server_seq_key ON escalation_contacts (server_seq);

CREATE INDEX hospitals_area_seq_idx ON hospitals (area_id, server_seq);
CREATE INDEX referral_centres_area_seq_idx ON referral_centres (area_id, server_seq);
CREATE INDEX escalation_contacts_area_seq_idx ON escalation_contacts (area_id, server_seq);

-- Down Migration

DROP TABLE escalation_contacts;
DROP TABLE referral_centres;
DROP TABLE hospitals;
