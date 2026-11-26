-- Up Migration

-- Older refresh rotations extended the session. Bring stored replacements
-- back to their original deadline, preserving any earlier expiry.
WITH RECURSIVE deadlines AS (
  SELECT t.id, t.replaced_by, t.expires_at
  FROM refresh_tokens t
  WHERE t.replaced_by IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM refresh_tokens parent WHERE parent.replaced_by = t.id)
  UNION ALL
  SELECT t.id, t.replaced_by, least(t.expires_at, parent.expires_at)
  FROM deadlines parent JOIN refresh_tokens t ON t.id = parent.replaced_by
)
UPDATE refresh_tokens t
SET expires_at = deadlines.expires_at
FROM deadlines
WHERE t.id = deadlines.id AND t.expires_at > deadlines.expires_at;

-- Down Migration

-- The original sliding expiries cannot be restored.
SELECT 1;
