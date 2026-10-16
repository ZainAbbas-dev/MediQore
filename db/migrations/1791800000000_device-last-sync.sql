-- Up Migration

-- M10 FE-1 (Phase 1 base): each LHW's last-sync time on the dashboard. Set by
-- the server's clock on every push and pull from the phone, so an LHW who syncs
-- with nothing new to send still counts as synced. last_seen_at also moves on
-- sign-in, which is not a sync.
ALTER TABLE devices ADD COLUMN last_sync_at timestamptz;

-- Down Migration

ALTER TABLE devices DROP COLUMN last_sync_at;
