-- Up Migration

-- Offline sync (P0-6, M3 FE-2): server_seq must follow commit order.
--
-- Devices pull with `server_seq > <last seen>`. If two transactions write synced
-- rows at the same time, the one holding the lower number could commit last; a
-- device that pulled in between would already have moved past that number and
-- never receive the row. Taking one transaction-level advisory lock before
-- numbering a row makes concurrent writers wait for each other, so numbers become
-- visible strictly in order. The lock is released automatically at commit or
-- rollback.
CREATE OR REPLACE FUNCTION assign_server_seq() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('mediqore.sync_server_seq'));
  NEW.server_seq := nextval('sync_server_seq');
  NEW.synced_at := now();
  RETURN NEW;
END;
$$;

-- Down Migration

CREATE OR REPLACE FUNCTION assign_server_seq() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.server_seq := nextval('sync_server_seq');
  NEW.synced_at := now();
  RETURN NEW;
END;
$$;
