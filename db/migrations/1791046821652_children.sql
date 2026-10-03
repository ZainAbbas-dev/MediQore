-- Up Migration

-- Children (Phase 3; used by M7, M8, M9): the shared child registry. Synced table.
-- Each child belongs to a household and can optionally link to the mother's
-- pregnancy file (roadmap, shared child registry).
CREATE TABLE children (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  household_id      uuid NOT NULL REFERENCES households (id),
  pregnancy_id      uuid REFERENCES pregnancies (id),
  name              text NOT NULL,
  date_of_birth     date NOT NULL,
  sex               text NOT NULL CHECK (sex IN ('female', 'male'))
);

CREATE INDEX children_household_id_idx ON children (household_id);

CREATE TRIGGER children_server_seq BEFORE INSERT OR UPDATE ON children FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER children_no_hard_delete BEFORE DELETE ON children FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE UNIQUE INDEX children_server_seq_key ON children (server_seq);
CREATE INDEX children_area_seq_idx ON children (area_id, server_seq);

-- Down Migration

DROP TABLE children;
