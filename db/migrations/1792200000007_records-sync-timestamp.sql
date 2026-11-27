-- Up Migration

ALTER TABLE devices ADD COLUMN last_records_sync_at timestamptz;

-- Down Migration

ALTER TABLE devices DROP COLUMN last_records_sync_at;
