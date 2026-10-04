-- Up Migration

-- M1 FE-3: area reassignment. A phone can still hold records the LHW made in
-- her old area that were not synced before the admin moved her. They keep the
-- area they were made in: the app sends it with each record, and the server
-- accepts the LHW's current area or the area she had before her last
-- reassignment. Set by the reassignment; one earlier area is kept.
ALTER TABLE lhw_profiles ADD COLUMN previous_area_id uuid REFERENCES areas (id);

-- Down Migration

ALTER TABLE lhw_profiles DROP COLUMN previous_area_id;
