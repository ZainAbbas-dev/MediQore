-- Up Migration

-- A portal round may cover several areas. Keep each existing campaign ID for
-- household records and the phone's area-scoped sync configuration.
ALTER TABLE campaigns ADD COLUMN round_id uuid NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE campaigns ADD CONSTRAINT campaigns_round_area_key UNIQUE (round_id, area_id);

-- Down Migration

ALTER TABLE campaigns DROP CONSTRAINT campaigns_round_area_key;
ALTER TABLE campaigns DROP COLUMN round_id;
