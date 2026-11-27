const db = require('../db/pool');
const logger = require('../utils/logger');
const { writeAudit } = require('./audit.service');
const { MODEL_RED } = require('./alerts.service');
const { createFcmSender, escalationMinutes, fcmSettings } = require('./alerts-fcm.service');

const POLL_MS = 15000;
const BATCH_SIZE = 20;
const TITLES = {
  emergency: 'Emergency alert',
  emergency_reminder: 'Emergency alert still unacknowledged',
  model_red: 'High-risk case',
};

// Server-owned alerts have an Internet receipt. The time-limit reminder is
// only eligible after the initial push has been attempted. Phone-owned
// records still appear in the portal as history.
const CANDIDATE = `
  WITH waiting AS (
    SELECT e.id, e.area_id, e.server_seq, e.raised_at,
           coalesce(contact.escalate_after_minutes, $1) AS escalation_minutes,
           initial.record_id IS NOT NULL AS notified
    FROM emergency_alerts e
    LEFT JOIN alert_push_events initial ON initial.record_id = e.id AND initial.stage = 'emergency'
    LEFT JOIN escalation_contacts contact ON contact.area_id = e.area_id AND contact.deleted_at IS NULL
    WHERE e.deleted_at IS NULL AND e.owner = 'server' AND e.status <> 'acknowledged'
      AND NOT EXISTS (
        SELECT 1 FROM alert_acknowledgements a
        WHERE a.alert_id = e.id AND a.area_id = e.area_id AND a.deleted_at IS NULL
      )
  ), candidates AS (
    SELECT w.id, w.area_id, w.server_seq, 'emergency' AS stage
    FROM waiting w WHERE NOT w.notified
    UNION ALL
    SELECT w.id, w.area_id, w.server_seq, 'emergency_reminder'
    FROM waiting w WHERE w.notified AND w.raised_at + make_interval(mins => w.escalation_minutes) <= now()
    UNION ALL
    SELECT r.id, r.area_id, r.server_seq, 'model_red'
    FROM risk_assessments r
    JOIN visits v ON v.id = r.visit_id AND v.area_id = r.area_id AND v.pregnancy_id = r.pregnancy_id
    WHERE r.deleted_at IS NULL AND v.deleted_at IS NULL AND ${MODEL_RED}
  )
  SELECT c.id, c.area_id, c.stage
  FROM candidates c
  WHERE NOT EXISTS (SELECT 1 FROM alert_push_events p WHERE p.record_id = c.id AND p.stage = c.stage)
  ORDER BY c.stage = 'model_red', c.server_seq
  LIMIT 1`;

async function deliver(client, event, send) {
  const { rows: recipients } = await client.query(
    `SELECT s.id, s.user_id, s.token
     FROM alert_push_subscriptions s
     JOIN users u ON u.id = s.user_id AND u.role = 'supervisor' AND u.is_active AND u.deleted_at IS NULL
     JOIN supervisor_areas a ON a.supervisor_id = s.user_id AND a.area_id = $1 AND a.deleted_at IS NULL
     LEFT JOIN role_permissions p ON p.role = u.role AND p.permission = 'alerts.view'
     WHERE coalesce(p.granted, true)`,
    [event.area_id],
  );
  const data = {
    title: TITLES[event.stage],
    body: 'Open the MediQore portal for details.',
    url: '/alerts',
  };
  const results = await Promise.allSettled(recipients.map(({ token }) => send(token, data)));
  let sent = 0;
  for (const [index, result] of results.entries()) {
    if (result.status !== 'fulfilled') continue;
    if (result.value?.unregistered) {
      const recipient = recipients[index];
      await client.query('DELETE FROM alert_push_subscriptions WHERE id = $1 AND user_id = $2 AND token = $3',
        [recipient.id, recipient.user_id, recipient.token]);
    } else {
      sent += 1;
    }
  }

  const attempted = recipients.length;
  let status = 'no_subscribers';
  if (attempted) status = sent === attempted ? 'sent' : sent ? 'partial' : 'failed';
  await client.query('INSERT INTO alert_push_events (record_id, stage, status) VALUES ($1, $2, $3)',
    [event.id, event.stage, status]);
  await writeAudit(client, {
    action: 'alert',
    entityType: event.stage === 'model_red' ? 'risk_assessments' : 'emergency_alerts',
    entityId: event.id,
    details: { event: event.stage, channel: 'internet', status, attempted, sent },
  });
}

async function processOne(send) {
  return db.withTransaction(async (client) => {
    const { rows: [{ locked }] } = await client.query(
      "SELECT pg_try_advisory_xact_lock(hashtext('mediqore.alert_push')) AS locked",
    );
    if (!locked) return false;
    const { rows: [event] } = await client.query(CANDIDATE, [escalationMinutes()]);
    if (!event) return false;

    // A portal acknowledgement and this dispatch lock the same alert. Read
    // the acknowledgement again after the lock in case one just committed.
    if (event.stage !== 'model_red') {
      const { rowCount } = await client.query(
        `SELECT id FROM emergency_alerts
         WHERE id = $1 AND area_id = $2 AND deleted_at IS NULL AND owner = 'server' AND status <> 'acknowledged'
         FOR NO KEY UPDATE`,
        [event.id, event.area_id],
      );
      if (!rowCount) return true;
      const { rowCount: acknowledged } = await client.query(
        'SELECT 1 FROM alert_acknowledgements WHERE alert_id = $1 AND area_id = $2 AND deleted_at IS NULL LIMIT 1',
        [event.id, event.area_id],
      );
      if (acknowledged) return true;
    }

    await deliver(client, event, send);
    return true;
  });
}

async function processAlertPush({ send }) {
  for (let count = 0; count < BATCH_SIZE; count += 1) {
    if (!(await processOne(send))) return;
  }
}

function startAlertsPushWorker() {
  const settings = fcmSettings();
  if (!settings) return async () => {};

  const send = createFcmSender(settings);
  let pending;
  const tick = () => {
    pending ??= processAlertPush({ send })
      .catch(() => logger.warn('Alert push processing failed'))
      .finally(() => { pending = undefined; });
  };
  tick();
  const timer = setInterval(tick, POLL_MS);
  timer.unref();

  return async () => {
    clearInterval(timer);
    await pending;
  };
}

module.exports = { processAlertPush, startAlertsPushWorker };
