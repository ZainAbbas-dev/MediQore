-- Up Migration

-- Geography (Phase 0; used by M1, M10): district > tehsil > Union Council > area.
-- Managed by admins on the portal (M10 FE-3); server-only reference data.

CREATE TABLE districts (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE tehsils (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  district_id uuid NOT NULL REFERENCES districts (id),
  name        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz,
  UNIQUE (district_id, name)
);

CREATE TABLE union_councils (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tehsil_id  uuid NOT NULL REFERENCES tehsils (id),
  name       text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (tehsil_id, name)
);

CREATE TABLE areas (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  union_council_id uuid NOT NULL REFERENCES union_councils (id),
  name             text NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  deleted_at       timestamptz,
  UNIQUE (union_council_id, name)
);

CREATE TRIGGER districts_touch_updated_at BEFORE UPDATE ON districts FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER tehsils_touch_updated_at BEFORE UPDATE ON tehsils FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER union_councils_touch_updated_at BEFORE UPDATE ON union_councils FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER areas_touch_updated_at BEFORE UPDATE ON areas FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER districts_no_hard_delete BEFORE DELETE ON districts FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER tehsils_no_hard_delete BEFORE DELETE ON tehsils FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER union_councils_no_hard_delete BEFORE DELETE ON union_councils FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER areas_no_hard_delete BEFORE DELETE ON areas FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();

-- Down Migration

DROP TABLE areas;
DROP TABLE union_councils;
DROP TABLE tehsils;
DROP TABLE districts;
