import './AlertCard.css';

const CHANNELS = { internet: 'Internet', sms: 'SMS', call: 'Call' };
const ATTEMPT_STATES = { sent: 'Sent', delivered: 'Delivered', failed: 'Failed', not_available: 'Unavailable' };
const PUSH_STATES = {
  sent: 'sent', partial: 'sent to some browsers', failed: 'failed', no_subscribers: 'had no subscribed browsers',
};

const formatTime = (value) => new Date(value).toLocaleString();
function formatDuration(seconds) {
  if (seconds >= 86400) return `${Math.floor(seconds / 86400)} d`;
  if (seconds >= 3600) return `${Math.floor(seconds / 3600)} hr`;
  if (seconds >= 60) return `${Math.floor(seconds / 60)} min`;
  return `${seconds} sec`;
}

export default function AlertCard({ alert, canAcknowledge, busyId, acknowledge, titleLevel = 'h2' }) {
  const Heading = titleLevel;
  const emergency = alert.type === 'emergency';
  const waiting = emergency && alert.status !== 'acknowledged';
  const title = alert.patient ? `${alert.patient.name} (${alert.patient.patientCode})` : 'Patient unavailable';
  const status = waiting ? (alert.overdue ? 'Unacknowledged' : 'Awaiting acknowledgement') : 'Acknowledged';

  return (
    <article
      className={waiting ? 'panel alert-card alert-card-waiting' : 'panel alert-card'}
      aria-labelledby={`alert-${alert.type}-${alert.id}`}
    >
      <header className="alert-card-header">
        <span className={emergency ? 'badge danger' : 'badge wait'}>{emergency ? 'Emergency' : 'High-risk case'}</span>
        {emergency && <span className={waiting ? 'badge wait' : 'badge ok'}>{status}</span>}
      </header>
      <Heading className="panel-title" id={`alert-${alert.type}-${alert.id}`}>{title}</Heading>
      <p className="muted">
        {alert.areaName} · <time dateTime={alert.occurredAt}>{formatTime(alert.occurredAt)}</time>
        {alert.ageSeconds != null && ` · ${formatDuration(alert.ageSeconds)} ago`}
      </p>
      {emergency && (
        <>
          <dl className="alert-details">
            {alert.lhw && (
              <div><dt>LHW</dt><dd>{alert.lhw.name}{alert.lhw.code && ` (${alert.lhw.code})`}</dd></div>
            )}
            {alert.triggeringSigns?.length > 0 && (
              <div><dt>Triggering signs</dt><dd>{alert.triggeringSigns.map((sign) => (
                sign.charAt(0).toUpperCase() + sign.slice(1).replaceAll('_', ' ')
              )).join(', ')}</dd></div>
            )}
            {alert.visitRecordedAt && (
              <div><dt>Visit recorded</dt><dd>{formatTime(alert.visitRecordedAt)}</dd></div>
            )}
            {alert.escalationSeconds != null && (
              <div><dt>Time to escalation</dt><dd>{formatDuration(alert.escalationSeconds)}</dd></div>
            )}
            {alert.acknowledgement && (
              <div>
                <dt>{alert.acknowledgement.method === 'supervisor_reached' ? 'Supervisor reached' : 'Acknowledged at'}</dt>
                <dd>
                  {formatTime(alert.acknowledgement.acknowledgedAt)}
                  {alert.acknowledgement.acknowledgedBy && ` · ${alert.acknowledgement.acknowledgedBy}`}
                </dd>
              </div>
            )}
          </dl>
          {alert.attempts?.length > 0 && (
            <ul className="alert-attempts" aria-label="Contact attempts">
              {alert.attempts.map((attempt, index) => (
                <li key={`${attempt.attemptedAt}-${index}`}>
                  {CHANNELS[attempt.channel]}{attempt.recipient === 'secondary' && ' · Secondary contact'}
                  {' · '}{ATTEMPT_STATES[attempt.status]}{' · '}{formatTime(attempt.attemptedAt)}
                </li>
              ))}
            </ul>
          )}
          {alert.reminder && (
            <p className="alert-push-note">Push reminder {PUSH_STATES[alert.reminder.status]} · {formatTime(alert.reminder.attemptedAt)}</p>
          )}
        </>
      )}
      {alert.push && (
        <p className="alert-push-note">Web push {PUSH_STATES[alert.push.status]} · {formatTime(alert.push.attemptedAt)}</p>
      )}
      {waiting && canAcknowledge && (
        <div className="row-actions">
          <button type="button" onClick={() => acknowledge(alert.id)} disabled={busyId !== null}>
            {busyId === alert.id ? 'Acknowledging…' : 'Acknowledge'}
          </button>
        </div>
      )}
    </article>
  );
}
