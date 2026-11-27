-- Up Migration

ALTER TABLE referrals ADD COLUMN follow_up_due_on date;
CREATE INDEX dashboard_risk_pregnancy_sequence
  ON risk_assessments (pregnancy_id, server_seq DESC) WHERE deleted_at IS NULL;
CREATE INDEX dashboard_visit_area_date
  ON visits (area_id, visited_at, created_by) WHERE deleted_at IS NULL;
CREATE INDEX dashboard_referral_area_date
  ON referrals (area_id, referred_at, created_by) WHERE deleted_at IS NULL;

-- Down Migration

DROP INDEX dashboard_referral_area_date;
DROP INDEX dashboard_visit_area_date;
DROP INDEX dashboard_risk_pregnancy_sequence;
ALTER TABLE referrals DROP COLUMN follow_up_due_on;
