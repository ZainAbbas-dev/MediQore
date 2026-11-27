import { useCallback, useEffect, useRef, useState } from 'react';
import { can, useAuth } from '../auth/context';
import {
  alertPushRegistration, canEnableAlertPush, disableAlertPush, enableAlertPush,
} from '../pwa/alerts-push';
import AlertCard from '../components/AlertCard';

const REFRESH_MS = 30000;

export default function AlertsPage() {
  const { request, user } = useAuth();
  const [before, setBefore] = useState(null);
  const [page, setPage] = useState(null);
  const [listError, setListError] = useState('');
  const [actionError, setActionError] = useState('');
  const [busyId, setBusyId] = useState(null);
  const [pushBusy, setPushBusy] = useState(false);
  const [pushEnabled, setPushEnabled] = useState(() => Boolean(alertPushRegistration(user?.id)));
  const generation = useRef(0);

  const load = useCallback(async () => {
    const sequence = ++generation.current;
    try {
      const result = await request(before ? `/alerts?before=${encodeURIComponent(before)}` : '/alerts');
      if (generation.current !== sequence) return;
      setPage(result);
      setListError('');
    } catch (error) {
      if (generation.current === sequence) setListError(error.message);
    }
  }, [before, request]);

  useEffect(() => {
    const initial = setTimeout(load, 0);
    const timer = before ? null : setInterval(load, REFRESH_MS);
    return () => {
      generation.current += 1;
      clearTimeout(initial);
      clearInterval(timer);
    };
  }, [before, load]);

  async function acknowledge(id) {
    setBusyId(id);
    setActionError('');
    try {
      const { alert } = await request(`/alerts/${id}/acknowledge`, { method: 'POST' });
      // Ignore a polling response started before this update was confirmed.
      generation.current += 1;
      setPage((current) => current && ({
        ...current, alerts: current.alerts.map((entry) => entry.id === id ? alert : entry),
      }));
    } catch (error) {
      setActionError(error.message);
    } finally {
      setBusyId(null);
    }
  }

  async function togglePush() {
    setPushBusy(true);
    setActionError('');
    try {
      if (pushEnabled) await disableAlertPush(request, user.id);
      else await enableAlertPush(request, user.id);
      setPushEnabled(!pushEnabled);
    } catch (error) {
      setActionError(error.message);
    } finally {
      setPushBusy(false);
    }
  }

  function goTo(cursor) {
    generation.current += 1;
    setPage(null);
    setBefore(cursor);
  }

  const pushOffered = user?.role === 'supervisor' && page?.pushAvailable && canEnableAlertPush();

  return (
    <>
      <div className="page-header">
        <div>
          <h1>Alerts</h1>
          <p className="page-subtitle">Emergency alerts and high-risk cases from your areas.</p>
        </div>
        <div className="toolbar wrap">
          <button type="button" className="secondary" onClick={load}>Refresh</button>
          {(pushOffered || pushEnabled) && (
            <button type="button" className="secondary" disabled={pushBusy} onClick={togglePush}>
              {pushEnabled ? 'Turn off web notifications' : 'Turn on web notifications'}
            </button>
          )}
        </div>
      </div>
      {listError && <p className="error" role="alert">{listError}</p>}
      {actionError && <p className="error" role="alert">{actionError}</p>}
      {!page && !listError && <p role="status" className="muted">Loading alerts…</p>}
      {page?.alerts.length === 0 && <p className="muted">No alerts to show.</p>}
      <div className="alerts-list">
        {page?.alerts.map((alert) => (
          <AlertCard
            key={`${alert.type}-${alert.id}`}
            alert={alert}
            canAcknowledge={can(user, 'alerts.acknowledge')}
            acknowledge={acknowledge}
            busyId={busyId}
          />
        ))}
      </div>
      {(before || page?.nextBefore) && (
        <nav className="toolbar wrap" aria-label="Alert pages">
          {before && <button type="button" className="secondary" onClick={() => goTo(null)}>Latest alerts</button>}
          {page?.nextBefore && (
            <button type="button" className="secondary" onClick={() => goTo(page.nextBefore)}>Older alerts</button>
          )}
        </nav>
      )}
    </>
  );
}
