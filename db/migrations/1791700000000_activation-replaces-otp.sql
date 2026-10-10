-- Up Migration

-- M1 FE-2 (Phase 1 revision): the first sign-in on a phone now uses the admin's
-- one-time activation code (activation_codes), so the earlier phone-approval
-- codes are no longer used. A phone counts as activated when
-- devices.activated_at is set; devices.verified_at only records an approval
-- under the earlier scheme, and such phones must be activated again.
DROP TABLE otp_codes;
DROP INDEX devices_pending_idx;

CREATE INDEX devices_activated_idx ON devices (user_id, activated_at) WHERE activated_at IS NOT NULL AND revoked_at IS NULL;
CREATE INDEX activation_codes_open_idx ON activation_codes (user_id)
  WHERE consumed_at IS NULL AND revoked_at IS NULL;

-- Down Migration

DROP INDEX activation_codes_open_idx;
DROP INDEX devices_activated_idx;

CREATE TABLE otp_codes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users (id),
  device_id   uuid REFERENCES devices (id),
  purpose     text NOT NULL CHECK (purpose IN ('first_login', 'new_device')),
  channel     text NOT NULL,
  code_hash   text NOT NULL,
  attempts    smallint NOT NULL DEFAULT 0,
  expires_at  timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX otp_codes_user_id_idx ON otp_codes (user_id);
CREATE INDEX devices_pending_idx ON devices (created_at) WHERE verified_at IS NULL AND revoked_at IS NULL;
