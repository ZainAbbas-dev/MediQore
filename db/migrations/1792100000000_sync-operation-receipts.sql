-- Up Migration

CREATE TABLE sync_operation_receipts (
  device_id uuid NOT NULL REFERENCES devices (id),
  operation_id uuid NOT NULL,
  request_hash text NOT NULL,
  result jsonb NOT NULL,
  PRIMARY KEY (device_id, operation_id)
);

-- Distinct edits of one record each get their own review entry. The legacy
-- de-duplication rule applies only to callers without an operation ID.
ALTER TABLE sync_conflicts ADD COLUMN operation_id uuid;
DROP INDEX sync_conflicts_one_pending_per_record;
CREATE UNIQUE INDEX sync_conflicts_pending_legacy_record
  ON sync_conflicts (table_name, incoming_record_id, reason) WHERE status = 'pending' AND operation_id IS NULL;
CREATE INDEX sync_conflicts_pending_device_record
  ON sync_conflicts (device_id, incoming_record_id) WHERE status = 'pending';

-- Down Migration

-- Recreate the old index first so rollback refuses to collapse distinct
-- pending conflicts. The migration runs in a transaction.
CREATE UNIQUE INDEX sync_conflicts_one_pending_per_record
  ON sync_conflicts (table_name, incoming_record_id, reason) WHERE status = 'pending';
DROP INDEX sync_conflicts_pending_device_record;
DROP INDEX sync_conflicts_pending_legacy_record;
ALTER TABLE sync_conflicts DROP COLUMN operation_id;
DROP TABLE sync_operation_receipts;
