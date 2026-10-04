-- Up Migration

-- M1 FE-1: the system issues a unique LHW ID when an admin creates an LHW:
-- LHW-00001, LHW-00002, ... The number comes from this sequence, so two admins
-- creating LHWs at the same moment never get the same ID.
CREATE SEQUENCE lhw_code_seq START WITH 1;

-- Pending phones waiting for an admin-issued code (M1 FE-2, decision 0002).
CREATE INDEX devices_pending_idx ON devices (created_at) WHERE verified_at IS NULL AND revoked_at IS NULL;

-- Down Migration

DROP INDEX devices_pending_idx;
DROP SEQUENCE lhw_code_seq;
