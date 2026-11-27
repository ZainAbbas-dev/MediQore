const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { writeAudit } = require('./audit.service');
const { managedAreaIds } = require('./scope.service');
const { and, placeConditions } = require('./dashboard.service');
const { fcmSettings, escalationMinutes } = require('./alerts-fcm.service');

// Keep the portal's model-only Red rule in sync with the worker and index.
const MODEL_RED = "r.final_level = 'red' AND r.model_level = 'high' AND NOT r.is_emergency AND r.rule_result <> 'emergency'";
const ALERT_ROWS = `
  SELECT e.id, e.area_id, e.pregnancy_id, e.server_seq, e.created_by, e.visit_id, e.risk_assessment_id,
         e.raised_at AS occurred_at,
         e.visit_recorded_at, e.status, e.owner, e.escalation_seconds, e.escalated_at,
         'emergency' AS type
  FROM emergency_alerts e
  WHERE e.deleted_at IS NULL
  UNION ALL
  SELECT r.id, r.area_id, r.pregnancy_id, r.server_seq, r.created_by, r.visit_id, NULL,
         coalesce(v.visited_at, r.synced_at),
         v.visited_at, NULL, NULL, NULL, NULL, 'model_red'
  FROM risk_assessments r
  JOIN visits v ON v.id = r.visit_id AND v.area_id = r.area_id AND v.pregnancy_id = r.pregnancy_id
  WHERE r.deleted_at IS NULL AND v.deleted_at IS NULL AND ${MODEL_RED}`;

const SELECT_PAGE = `
  SELECT p.*, a.name AS area_name, w.name AS patient_name, w.patient_code,
    lhw.full_name AS lhw_name, profile.lhw_code, risk.triggered_rules,
    ack.acknowledged_at, ack.method, ack.acknowledged_by, attempts.entries AS attempts,
    push.attempted_at AS push_at, push.status AS push_status,
    reminder.attempted_at AS reminder_at, reminder.status AS reminder_status,
    p.owner = 'server' AND
      p.occurred_at + make_interval(mins => coalesce(contact.escalate_after_minutes, $3)) <= now() AS overdue
  FROM page p
  JOIN areas a ON a.id = p.area_id
  LEFT JOIN pregnancies g ON g.id = p.pregnancy_id AND g.area_id = p.area_id AND g.deleted_at IS NULL
  LEFT JOIN women w ON w.id = g.woman_id AND w.area_id = p.area_id AND w.deleted_at IS NULL
  LEFT JOIN users lhw ON lhw.id = p.created_by AND lhw.role = 'lhw'
  LEFT JOIN lhw_profiles profile ON profile.user_id = lhw.id
  LEFT JOIN escalation_contacts contact ON contact.area_id = p.area_id AND contact.deleted_at IS NULL
  LEFT JOIN risk_assessments risk ON p.type = 'emergency' AND risk.area_id = p.area_id
    AND risk.pregnancy_id = p.pregnancy_id AND risk.deleted_at IS NULL
    AND (risk.id = p.risk_assessment_id OR (p.risk_assessment_id IS NULL AND risk.visit_id = p.visit_id))
  LEFT JOIN LATERAL (
    SELECT k.acknowledged_at, k.method, u.full_name AS acknowledged_by
    FROM alert_acknowledgements k JOIN users u ON u.id = k.created_by
    WHERE p.type = 'emergency' AND k.alert_id = p.id AND k.area_id = p.area_id AND k.deleted_at IS NULL
    ORDER BY k.acknowledged_at, k.server_seq LIMIT 1
  ) ack ON true
  LEFT JOIN LATERAL (
    SELECT jsonb_agg(jsonb_build_object(
      'channel', t.channel, 'recipient', t.recipient, 'status', t.status, 'attemptedAt', t.attempted_at
    ) ORDER BY t.attempted_at, t.server_seq) AS entries
    FROM alert_attempts t
    WHERE p.type = 'emergency' AND t.alert_id = p.id AND t.area_id = p.area_id AND t.deleted_at IS NULL
  ) attempts ON true
  LEFT JOIN alert_push_events push ON push.record_id = p.id AND push.stage = p.type
  LEFT JOIN alert_push_events reminder ON reminder.record_id = p.id
    AND p.type = 'emergency' AND reminder.stage = 'emergency_reminder'
  ORDER BY p.server_seq DESC`;

function toAlert(row) {
  const acknowledged = Boolean(row.acknowledged_at || row.status === 'acknowledged');
  const reminder = row.reminder_at ? { status: row.reminder_status, attemptedAt: row.reminder_at } : null;
  const escalationAt = row.escalated_at ?? row.reminder_at;
  return {
    id: row.id,
    type: row.type,
    areaId: row.area_id,
    areaName: row.area_name,
    patient: row.patient_code ? { name: row.patient_name, patientCode: row.patient_code } : null,
    lhw: row.lhw_name ? { name: row.lhw_name, code: row.lhw_code } : null,
    triggeringSigns: Array.isArray(row.triggered_rules)
      ? row.triggered_rules.filter((rule) => typeof rule === 'string') : [],
    occurredAt: row.occurred_at,
    ageSeconds: Math.max(0, Math.floor((Date.now() - row.occurred_at) / 1000)),
    visitRecordedAt: row.visit_recorded_at,
    status: acknowledged ? 'acknowledged' : row.status,
    overdue: Boolean(row.overdue && !acknowledged),
    escalatedAt: row.escalated_at,
    escalationSeconds: row.escalation_seconds ?? (escalationAt
      ? Math.max(0, Math.floor((escalationAt - row.occurred_at) / 1000))
      : null),
    attempts: row.attempts ?? [],
    acknowledgement: row.acknowledged_at ? {
      acknowledgedAt: row.acknowledged_at, method: row.method, acknowledgedBy: row.acknowledged_by,
    } : null,
    push: row.push_at ? { status: row.push_status, attemptedAt: row.push_at } : null,
    reminder,
  };
}

async function list(viewer, { before, limit, emergencyOnly, ...filters }) {
  const areaIds = await managedAreaIds(db, viewer);
  const params = [before ?? null, emergencyOnly, escalationMinutes(), limit + 1];
  const scope = placeConditions(params, { ...filters, areaIds }, 'area_id', 'created_by', 'occurred_at');
  const { rows } = await db.query(
    `WITH alerts AS (${ALERT_ROWS}), page AS (
       SELECT * FROM alerts
       WHERE ($1::bigint IS NULL OR server_seq < $1) AND (NOT $2::boolean OR type = 'emergency')${and(scope)}
       ORDER BY server_seq DESC LIMIT $4
     )
     ${SELECT_PAGE}`,
    params,
  );
  return {
    alerts: rows.slice(0, limit).map(toAlert),
    nextBefore: rows.length > limit ? rows[limit - 1].server_seq : null,
    pushAvailable: Boolean(fcmSettings()),
  };
}

async function acknowledge(viewer, id) {
  return db.withTransaction(async (client) => {
    const areas = await managedAreaIds(client, viewer);
    const { rows: [alert] } = await client.query(
      `SELECT area_id, status FROM emergency_alerts
       WHERE id = $1 AND deleted_at IS NULL AND ($2::uuid[] IS NULL OR area_id = ANY($2))
       FOR NO KEY UPDATE`,
      [id, areas],
    );
    if (!alert) throw new AppError(404, 'NOT_FOUND', 'No emergency alert with this ID in your areas');

    const { rowCount } = await client.query(
      `SELECT 1 FROM alert_acknowledgements WHERE alert_id = $1 AND area_id = $2 AND deleted_at IS NULL LIMIT 1`,
      [id, alert.area_id],
    );
    if (alert.status !== 'acknowledged' && !rowCount) {
      await client.query(
        `INSERT INTO alert_acknowledgements (alert_id, area_id, created_by, method, acknowledged_at)
         VALUES ($1, $2, $3, 'dashboard', clock_timestamp())`,
        [id, alert.area_id, viewer.id],
      );
      await client.query("UPDATE emergency_alerts SET status = 'acknowledged' WHERE id = $1", [id]);
      await writeAudit(client, {
        userId: viewer.id,
        action: 'alert',
        entityType: 'emergency_alerts',
        entityId: id,
        details: { method: 'dashboard', event: 'acknowledged' },
      });
    }

    const { rows: [row] } = await client.query(
      `WITH alerts AS (${ALERT_ROWS}), page AS (
         SELECT * FROM alerts WHERE id = $1 AND area_id = $2 AND type = 'emergency'
       )
       ${SELECT_PAGE}`,
      [id, alert.area_id, escalationMinutes()],
    );
    return { alert: toAlert(row) };
  });
}

async function subscribe(viewer, token) {
  if (!fcmSettings()) throw new AppError(503, 'PUSH_NOT_CONFIGURED', 'Web push is unavailable');
  const { rows: [subscription] } = await db.query(
    `INSERT INTO alert_push_subscriptions (user_id, token) VALUES ($1, $2)
     ON CONFLICT (token) DO UPDATE SET user_id = EXCLUDED.user_id, updated_at = now()
     RETURNING id`,
    [viewer.id, token],
  );
  return { id: subscription.id };
}

async function unsubscribe(viewer, id) {
  await db.query('DELETE FROM alert_push_subscriptions WHERE id = $1 AND user_id = $2', [id, viewer.id]);
}

module.exports = { list, acknowledge, subscribe, unsubscribe, MODEL_RED };
