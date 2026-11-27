-- Up Migration

CREATE TABLE alert_push_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users (id),
  token text NOT NULL UNIQUE,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX alert_push_subscriptions_user_idx ON alert_push_subscriptions (user_id);

-- The outcome of each initial notification or one-time reminder. FCM acceptance
-- means sent, not receipt or acknowledgement by a supervisor.
CREATE TABLE alert_push_events (
  record_id uuid NOT NULL,
  stage text NOT NULL CHECK (stage IN ('emergency', 'emergency_reminder', 'model_red')),
  status text NOT NULL CHECK (status IN ('sent', 'partial', 'failed', 'no_subscribers')),
  attempted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (record_id, stage)
);

CREATE INDEX emergency_alerts_server_waiting_idx ON emergency_alerts (server_seq)
  WHERE deleted_at IS NULL AND owner = 'server' AND status <> 'acknowledged';
CREATE INDEX risk_assessments_model_red_idx ON risk_assessments (server_seq)
  WHERE deleted_at IS NULL AND final_level = 'red' AND model_level = 'high'
    AND NOT is_emergency AND rule_result <> 'emergency';

-- Down Migration

DROP INDEX risk_assessments_model_red_idx;
DROP INDEX emergency_alerts_server_waiting_idx;
DROP TABLE alert_push_events;
DROP TABLE alert_push_subscriptions;
