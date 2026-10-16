-- Up Migration

-- M1 FE-2, M3 FE-2: refresh tokens are replaced at every sync. On a weak mobile
-- network the phone can lose the answer after the server has already replaced
-- its token; without a way back, the LHW would have to sign in again online.
-- replaced_by links a used token to the one that replaced it, so the server can
-- accept the old token once more while that replacement has never been used
-- (api/src/services/tokens.service.js).
ALTER TABLE refresh_tokens ADD COLUMN replaced_by uuid REFERENCES refresh_tokens (id);

-- Down Migration

ALTER TABLE refresh_tokens DROP COLUMN replaced_by;
