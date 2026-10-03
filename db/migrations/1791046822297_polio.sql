-- Up Migration

-- Polio (Phase 3; used by M7): campaign rounds, house-to-house records, refusals
-- and revisits. Synced tables.
--
-- Zero-dose identification (M7 FE-3) needs to know which children received OPV in
-- a round; how that is recorded per child is decided with Phase 3 and added in a
-- later migration.

-- Campaign rounds created on the portal and pulled to devices (roadmap, Module 7).
CREATE TABLE campaigns (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  name              text NOT NULL,
  starts_on         date NOT NULL,
  ends_on           date NOT NULL,
  CHECK (ends_on >= starts_on)
);

-- House-to-house record for a household in a round (M7 FE-1).
CREATE TABLE campaign_household_records (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq          bigint NOT NULL,
  area_id             uuid NOT NULL REFERENCES areas (id),
  created_by          uuid NOT NULL REFERENCES users (id),
  created_on_device   timestamptz,
  synced_at           timestamptz NOT NULL,
  deleted_at          timestamptz,
  campaign_id         uuid NOT NULL REFERENCES campaigns (id),
  household_id        uuid NOT NULL REFERENCES households (id),
  visited_on          date NOT NULL,
  children_under_5    smallint NOT NULL CHECK (children_under_5 >= 0),
  children_vaccinated smallint NOT NULL CHECK (children_vaccinated >= 0),
  vaccine_type        text NOT NULL DEFAULT 'OPV',
  CHECK (children_vaccinated <= children_under_5)
);

-- Refusal with its stated reason (M7 FE-2).
CREATE TABLE refusals (
  id                           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq                   bigint NOT NULL,
  area_id                      uuid NOT NULL REFERENCES areas (id),
  created_by                   uuid NOT NULL REFERENCES users (id),
  created_on_device            timestamptz,
  synced_at                    timestamptz NOT NULL,
  deleted_at                   timestamptz,
  campaign_household_record_id uuid NOT NULL REFERENCES campaign_household_records (id),
  reason                       text NOT NULL CHECK (reason IN ('religious_concern', 'misinformation', 'past_reaction', 'absent_family'))
);

-- Revisit scheduled automatically in the same round for each refusal (M7 FE-2).
CREATE TABLE revisits (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid NOT NULL REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  refusal_id        uuid NOT NULL REFERENCES refusals (id),
  scheduled_on      date NOT NULL,
  completed_at      timestamptz,
  outcome           text
);

CREATE INDEX campaign_household_records_campaign_idx ON campaign_household_records (campaign_id, household_id);
CREATE INDEX refusals_record_idx ON refusals (campaign_household_record_id);
CREATE INDEX revisits_refusal_id_idx ON revisits (refusal_id);

CREATE TRIGGER campaigns_server_seq BEFORE INSERT OR UPDATE ON campaigns FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER campaign_household_records_server_seq BEFORE INSERT OR UPDATE ON campaign_household_records FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER refusals_server_seq BEFORE INSERT OR UPDATE ON refusals FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER revisits_server_seq BEFORE INSERT OR UPDATE ON revisits FOR EACH ROW EXECUTE FUNCTION assign_server_seq();

CREATE TRIGGER campaigns_no_hard_delete BEFORE DELETE ON campaigns FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER campaign_household_records_no_hard_delete BEFORE DELETE ON campaign_household_records FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER refusals_no_hard_delete BEFORE DELETE ON refusals FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER revisits_no_hard_delete BEFORE DELETE ON revisits FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();

CREATE UNIQUE INDEX campaigns_server_seq_key ON campaigns (server_seq);
CREATE UNIQUE INDEX campaign_household_records_server_seq_key ON campaign_household_records (server_seq);
CREATE UNIQUE INDEX refusals_server_seq_key ON refusals (server_seq);
CREATE UNIQUE INDEX revisits_server_seq_key ON revisits (server_seq);

CREATE INDEX campaigns_area_seq_idx ON campaigns (area_id, server_seq);
CREATE INDEX campaign_household_records_area_seq_idx ON campaign_household_records (area_id, server_seq);
CREATE INDEX refusals_area_seq_idx ON refusals (area_id, server_seq);
CREATE INDEX revisits_area_seq_idx ON revisits (area_id, server_seq);

-- Down Migration

DROP TABLE revisits;
DROP TABLE refusals;
DROP TABLE campaign_household_records;
DROP TABLE campaigns;
