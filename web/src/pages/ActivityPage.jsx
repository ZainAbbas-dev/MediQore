import { useEffect, useState } from 'react';
import { can, useAuth } from '../auth/context';
import Dialog from '../components/Dialog';
import './ActivityPage.css';

const PAKISTAN_DATE = new Intl.DateTimeFormat('en-GB', {
  day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Asia/Karachi',
});
const formatDate = (value) => PAKISTAN_DATE.format(new Date(value));

function weekRange(start) {
  const end = new Date(`${start}T00:00:00Z`);
  end.setUTCDate(end.getUTCDate() + 6);
  return `${formatDate(start)} – ${formatDate(end)}`;
}

const STATUS = {
  active: { label: 'Active', style: 'ok' },
  insufficient_history: { label: 'Not enough synced data', style: 'off' },
  unusual_inactivity: { label: 'Unusual inactivity', style: 'danger' },
  excluded: { label: 'Excluded week', style: 'off' },
  not_synced: { label: 'Not synced yet', style: 'wait' },
};

export function InactivityStatus({ inactivity, lastSyncAt }) {
  const entry = STATUS[inactivity?.status];
  if (!entry) return <span aria-label="Activity status unavailable">–</span>;

  let label = entry.label;
  if (inactivity.status === 'excluded' && inactivity.exclusion) label = `Excluded for ${inactivity.exclusion}`;
  if (inactivity.status === 'not_synced' && lastSyncAt) label = `Not synced since ${formatDate(lastSyncAt)}`;

  return (
    <>
      <span className={`badge activity-status ${entry.style}`}>{label}</span>
      {inactivity.status === 'unusual_inactivity' && (
        <small className="activity-prompt">Verify field activity with this LHW.</small>
      )}
    </>
  );
}

function ExclusionsDialog({ worker, weekStart, canManage, onClose, onChanged }) {
  const { request } = useAuth();
  const path = `/inactivity/${worker.id}/exclusions`;
  const [exclusions, setExclusions] = useState(null);
  const [date, setDate] = useState(weekStart);
  const [kind, setKind] = useState('leave');
  const [pending, setPending] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    let ignore = false;
    request(path).then(
      (data) => { if (!ignore) setExclusions(data.exclusions); },
      (failure) => { if (!ignore) setError(failure.message); },
    );
    return () => { ignore = true; };
  }, [path, request]);

  async function save(event) {
    event.preventDefault();
    if (new Date(`${date}T00:00:00Z`).getUTCDay() !== 1) {
      setError('Choose a Monday as the week start.');
      return;
    }
    setPending(true);
    setError('');
    try {
      const { exclusion } = await request(`${path}/${date}`, { method: 'PUT', body: { kind } });
      setExclusions((rows) => [...rows.filter((row) => row.weekStart !== date), exclusion]
        .sort((a, b) => b.weekStart.localeCompare(a.weekStart)));
      onChanged();
    } catch (failure) {
      setError(failure.message);
    } finally {
      setPending(false);
    }
  }

  async function remove(week) {
    setPending(true);
    setError('');
    try {
      await request(`${path}/${week}`, { method: 'DELETE' });
      setExclusions((rows) => rows.filter((row) => row.weekStart !== week));
      onChanged();
    } catch (failure) {
      setError(failure.message);
    } finally {
      setPending(false);
    }
  }

  return (
    <Dialog title={`Excluded weeks for ${worker.fullName}`}>
      {canManage && (
        <form className="toolbar wrap activity-exclusion-form" onSubmit={save}>
          <label className="field">
            Week start (Monday)
            <input type="date" min="0001-01-01" max="9999-12-31" value={date} onChange={(event) => setDate(event.target.value)} required />
          </label>
          <label className="field">
            Reason
            <select value={kind} onChange={(event) => setKind(event.target.value)}>
              <option value="leave">Leave</option>
              <option value="campaign">Campaign</option>
            </select>
          </label>
          <button disabled={!exclusions || pending}>Save excluded week</button>
        </form>
      )}
      {error && <p className="error" role="alert">{error}</p>}
      {!exclusions && !error && <p role="status">Loading excluded weeks…</p>}
      {exclusions?.length === 0 && <p className="muted">No excluded weeks.</p>}
      {exclusions?.length > 0 && (
        <ul className="activity-exclusions">
          {exclusions.map((entry) => (
            <li key={entry.id}>
              <div>
                <strong>{formatDate(entry.weekStart)}</strong>
                <span>{entry.kind === 'leave' ? 'Leave week' : 'Campaign week'}</span>
              </div>
              {canManage && (
                <button
                  type="button"
                  className="secondary"
                  aria-label={`Remove exclusion for ${formatDate(entry.weekStart)}`}
                  disabled={pending}
                  onClick={() => remove(entry.weekStart)}
                >
                  Remove
                </button>
              )}
            </li>
          ))}
        </ul>
      )}
      <div className="dialog-actions">
        <button type="button" className="secondary" onClick={onClose}>Close</button>
      </div>
    </Dialog>
  );
}

export default function ActivityPage() {
  const { request, user } = useAuth();
  const [data, setData] = useState(null);
  const [error, setError] = useState('');
  const [refresh, setRefresh] = useState(0);
  const [selected, setSelected] = useState(null);
  const canManage = can(user, 'inactivity.manage');

  useEffect(() => {
    let ignore = false;
    request('/inactivity').then(
      (result) => {
        if (ignore) return;
        setData(result);
        setError('');
      },
      (failure) => { if (!ignore) setError(failure.message); },
    );
    return () => { ignore = true; };
  }, [request, refresh]);

  const reload = () => setRefresh((version) => version + 1);
  return (
    <>
      <header className="page-header">
        <div>
          <h1>LHW activity</h1>
          {data && <p className="page-subtitle">Completed week of {weekRange(data.weekStart)} (Pakistan time)</p>}
        </div>
        <button type="button" className="secondary" onClick={reload}>Refresh</button>
      </header>
      {error && <p className="error" role="alert">{error}</p>}
      {!data && !error && <p role="status">Loading LHW activity…</p>}
      {data?.lhws.length === 0 && <p className="muted">No LHWs in your areas.</p>}
      {data?.lhws.length > 0 && (
        <div className="activity-workers">
          {data.lhws.map((worker) => (
            <article className="card activity-worker" key={worker.id}>
              <div>
                <h2>{worker.fullName}</h2>
                <p className="muted">{worker.lhwCode} · {worker.area}</p>
              </div>
              <dl className="activity-week-data">
                <div><dt>Visits in week</dt><dd>{worker.inactivity.visits ?? '–'}</dd></div>
                <div><dt>Last sync</dt><dd>{worker.lastSyncAt ? formatDate(worker.lastSyncAt) : 'Never'}</dd></div>
                <div><dt>Activity status</dt><dd><InactivityStatus inactivity={worker.inactivity} lastSyncAt={worker.lastSyncAt} /></dd></div>
              </dl>
              <button
                className="secondary"
                type="button"
                aria-label={`${canManage ? 'Manage' : 'View'} excluded weeks for ${worker.fullName}`}
                onClick={() => setSelected(worker)}
              >
                {canManage ? 'Manage excluded weeks' : 'View excluded weeks'}
              </button>
            </article>
          ))}
        </div>
      )}
      {selected && (
        <ExclusionsDialog
          worker={selected}
          weekStart={data.weekStart}
          canManage={canManage}
          onClose={() => setSelected(null)}
          onChanged={reload}
        />
      )}
    </>
  );
}
