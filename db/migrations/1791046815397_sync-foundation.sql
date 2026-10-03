-- Up Migration

-- Shared building blocks for schema v1 (roadmap P0-4, "Architecture and conventions").
--
-- Synced tables (field data and anything devices pull) all carry the same base columns:
--   id                uuid         UUID v4 generated on the device (or by the server for web-created rows)
--   server_seq        bigint       assigned by the server on every insert and update (never by the device)
--   area_id           uuid         area the row belongs to; every query is scoped by area
--   created_by        uuid         user who created the row
--   created_on_device timestamptz  device clock at creation; informational only, never used for ordering (LI-7)
--   synced_at         timestamptz  server time when this version of the row was accepted
--   deleted_at        timestamptz  soft delete marker; rows are never hard-deleted

-- One sequence for all synced tables, so GET /sync/pull?since=<n> works across tables.
CREATE SEQUENCE sync_server_seq AS bigint;

-- Gives every new or changed row the next sequence number and the server receive time.
CREATE FUNCTION assign_server_seq() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.server_seq := nextval('sync_server_seq');
  NEW.synced_at := now();
  RETURN NEW;
END;
$$;

-- Soft deletes only: set deleted_at instead of deleting the row.
CREATE FUNCTION prevent_hard_delete() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Rows in % are soft-deleted only: set deleted_at instead of deleting', TG_TABLE_NAME
    USING ERRCODE = 'restrict_violation';
END;
$$;

-- Keeps updated_at current on server-managed (non-synced) tables.
CREATE FUNCTION touch_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- Down Migration

DROP FUNCTION touch_updated_at();
DROP FUNCTION prevent_hard_delete();
DROP FUNCTION assign_server_seq();
DROP SEQUENCE sync_server_seq;
