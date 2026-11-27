-- Up Migration

CREATE INDEX visits_lhw_visited_at_idx ON visits (created_by, visited_at) WHERE deleted_at IS NULL;

-- Down Migration

DROP INDEX visits_lhw_visited_at_idx;
