// M10 FE-3: the audit log viewer, for admins. Every create, edit, delete,
// referral, alert, sign-in and sync conflict, newest first, with who did it and
// when. Filters: user, action, record type and dates (whole days, Pakistan time).
import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../auth/context';

const ACTION_LABELS = {
  create: 'Created',
  edit: 'Changed',
  delete: 'Deleted',
  referral: 'Referral',
  alert: 'Alert',
  login: 'Sign-in',
  sync_conflict: 'Sync conflict',
};

const show = (value) => (value === null || value === undefined || value === '' ? '–' : String(value));

// The details of an entry as short lines: changes as "field: from → to".
function detailLines(details) {
  const lines = [];
  for (const [key, value] of Object.entries(details ?? {})) {
    if (key === 'changes' && value && typeof value === 'object') {
      for (const [field, change] of Object.entries(value)) {
        if (change && typeof change === 'object' && 'from' in change) {
          lines.push(`${field}: ${show(change.from)} → ${show(change.to)}`);
        } else {
          lines.push(`${field}: ${JSON.stringify(change)}`);
        }
      }
    } else {
      lines.push(`${key}: ${typeof value === 'object' ? JSON.stringify(value) : show(value)}`);
    }
  }
  return lines;
}

const EMPTY_FILTERS = { user: '', action: '', entityType: '', from: '', to: '' };

export default function AuditPage() {
  const { request } = useAuth();
  const [filters, setFilters] = useState(EMPTY_FILTERS);
  const [entries, setEntries] = useState(null);
  const [nextBefore, setNextBefore] = useState(null);
  const [choices, setChoices] = useState({ actions: [], entityTypes: [] });
  const [error, setError] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);

  const query = useCallback(
    (before) => {
      const params = new URLSearchParams();
      for (const [key, value] of Object.entries(filters)) if (value.trim()) params.set(key, value.trim());
      if (before) params.set('before', String(before));
      const text = params.toString();
      return request(`/admin/audit${text ? `?${text}` : ''}`);
    },
    [request, filters],
  );

  useEffect(() => {
    let cancelled = false;
    query()
      .then((data) => {
        if (cancelled) return;
        setEntries(data.entries);
        setNextBefore(data.nextBefore);
        setChoices({ actions: data.actions, entityTypes: data.entityTypes });
        setError(null);
      })
      .catch((err) => {
        if (!cancelled) setError(err.message);
      });
    return () => {
      cancelled = true;
    };
  }, [query]);

  async function loadMore() {
    setLoadingMore(true);
    try {
      const data = await query(nextBefore);
      setEntries((current) => [...current, ...data.entries]);
      setNextBefore(data.nextBefore);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoadingMore(false);
    }
  }

  const set = (field) => (e) => setFilters((f) => ({ ...f, [field]: e.target.value }));

  return (
    <>
      <h1>Audit log</h1>
      <p className="muted">
        Every record created, changed or deleted, every sign-in and every sync conflict, with who did it and when. Nothing
        in the log can be changed or removed.
      </p>
      <div className="toolbar wrap">
        <label htmlFor="audit-user">User</label>
        <input id="audit-user" type="search" placeholder="Username or name" value={filters.user} onChange={set('user')} />
        <label htmlFor="audit-action">Action</label>
        <select id="audit-action" value={filters.action} onChange={set('action')}>
          <option value="">All</option>
          {choices.actions.map((action) => (
            <option key={action} value={action}>
              {ACTION_LABELS[action] ?? action}
            </option>
          ))}
        </select>
        <label htmlFor="audit-type">Record</label>
        <select id="audit-type" value={filters.entityType} onChange={set('entityType')}>
          <option value="">All</option>
          {choices.entityTypes.map((type) => (
            <option key={type} value={type}>
              {type}
            </option>
          ))}
        </select>
        <label htmlFor="audit-from">From</label>
        <input id="audit-from" type="date" value={filters.from} onChange={set('from')} />
        <label htmlFor="audit-to">To</label>
        <input id="audit-to" type="date" value={filters.to} onChange={set('to')} />
        <button type="button" className="secondary" onClick={() => setFilters(EMPTY_FILTERS)}>
          Clear
        </button>
      </div>
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      {entries && entries.length === 0 && <p className="muted">Nothing in the log matches.</p>}
      {entries && entries.length > 0 && (
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>When</th>
                <th>Who</th>
                <th>Action</th>
                <th>Record</th>
                <th>Details</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((entry) => (
                <tr key={entry.id}>
                  <td className="nowrap">{new Date(entry.occurredAt).toLocaleString()}</td>
                  <td>
                    {entry.user ? (
                      <>
                        {entry.user.username}
                        <div className="muted">{entry.user.role}</div>
                      </>
                    ) : (
                      <span className="muted">Unknown</span>
                    )}
                  </td>
                  <td>{ACTION_LABELS[entry.action] ?? entry.action}</td>
                  <td>
                    {entry.entityType ?? '–'}
                    {(entry.entityLabel || entry.entityId) && (
                      <div className="muted mono" title={entry.entityId ?? undefined}>
                        {entry.entityLabel ?? entry.entityId.slice(0, 8)}
                      </div>
                    )}
                  </td>
                  <td className="audit-details">
                    {detailLines(entry.details).map((line) => (
                      <div key={line}>{line}</div>
                    ))}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {nextBefore && (
        <button type="button" className="secondary" onClick={loadMore} disabled={loadingMore}>
          Show older entries
        </button>
      )}
    </>
  );
}
