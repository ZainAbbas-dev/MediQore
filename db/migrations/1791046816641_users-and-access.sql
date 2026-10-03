-- Up Migration

-- Users and access (Phase 0–1; used by M1): accounts, LHW profiles, supervisor areas,
-- devices, refresh tokens and OTP codes. Server-only; never synced to devices as rows.

CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role          text NOT NULL CHECK (role IN ('lhw', 'supervisor', 'admin')),
  username      text NOT NULL,                -- login ID issued by the admin (M1 FE-1)
  full_name     text NOT NULL,
  phone         text,                         -- for supervisors: registered number for Layer 3 calls (M5 FE-2)
  email         text,                         -- OTP channel is decided in P0-11
  password_hash text NOT NULL,                -- bcrypt
  is_active     boolean NOT NULL DEFAULT true, -- deactivated accounts are refused at next sync (M1 FE-3)
  last_login_at timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);

CREATE UNIQUE INDEX users_username_key ON users (lower(username));

-- One profile per LHW. lhw_code is the unique LHW ID; offline patient IDs are
-- built from it plus a local counter (M2 FE-1).
CREATE TABLE lhw_profiles (
  user_id    uuid PRIMARY KEY REFERENCES users (id),
  lhw_code   text NOT NULL UNIQUE,
  area_id    uuid NOT NULL REFERENCES areas (id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

-- Areas assigned to each supervisor; drives area scoping for supervisors.
CREATE TABLE supervisor_areas (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supervisor_id uuid NOT NULL REFERENCES users (id),
  area_id       uuid NOT NULL REFERENCES areas (id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);

CREATE UNIQUE INDEX supervisor_areas_active_key ON supervisor_areas (supervisor_id, area_id) WHERE deleted_at IS NULL;

-- Phones a user has signed in on. id is the app installation UUID generated on the
-- device. A new device needs OTP verification (M1 FE-2).
CREATE TABLE devices (
  id           uuid PRIMARY KEY,
  user_id      uuid NOT NULL REFERENCES users (id),
  model        text,
  fcm_token    text,                          -- Layer 1 push for the supervisor alert role (M5 FE-2)
  verified_at  timestamptz,
  last_seen_at timestamptz,
  revoked_at   timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX devices_user_id_idx ON devices (user_id);

-- Refresh tokens are stored hashed and revoked on logout or deactivation (M1 FE-2, FE-3).
CREATE TABLE refresh_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users (id),
  device_id  uuid REFERENCES devices (id),
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX refresh_tokens_user_id_idx ON refresh_tokens (user_id);

-- One-time codes for first login and new devices (M1 FE-2). Codes are stored hashed.
CREATE TABLE otp_codes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users (id),
  device_id   uuid REFERENCES devices (id),
  purpose     text NOT NULL CHECK (purpose IN ('first_login', 'new_device')),
  channel     text NOT NULL,                 -- decided in P0-11 (for example email or admin-issued)
  code_hash   text NOT NULL,
  attempts    smallint NOT NULL DEFAULT 0,
  expires_at  timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX otp_codes_user_id_idx ON otp_codes (user_id);

CREATE TRIGGER users_touch_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER lhw_profiles_touch_updated_at BEFORE UPDATE ON lhw_profiles FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER users_no_hard_delete BEFORE DELETE ON users FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER lhw_profiles_no_hard_delete BEFORE DELETE ON lhw_profiles FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER supervisor_areas_no_hard_delete BEFORE DELETE ON supervisor_areas FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();

-- Down Migration

DROP TABLE otp_codes;
DROP TABLE refresh_tokens;
DROP TABLE devices;
DROP TABLE supervisor_areas;
DROP TABLE lhw_profiles;
DROP TABLE users;
