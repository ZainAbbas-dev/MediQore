import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { can, useAuth } from '../auth/context';
import AlertCard from './AlertCard';

export default function DashboardAlerts({ query, refreshes, onAcknowledged }) {
  const { request, user } = useAuth();
  const [alerts, setAlerts] = useState(null);
  const [error, setError] = useState('');
  const [busyId, setBusyId] = useState(null);

  useEffect(() => {
    let cancelled = false;
    request(`/alerts${query}`).then((result) => {
      if (cancelled) return;
      setAlerts(result.alerts);
      setError('');
    }).catch((failure) => {
      if (!cancelled) setError(failure.message);
    });
    return () => { cancelled = true; };
  }, [request, query, refreshes]);

  async function acknowledge(id) {
    setBusyId(id);
    setError('');
    try {
      const { alert } = await request(`/alerts/${id}/acknowledge`, { method: 'POST' });
      setAlerts((current) => current?.map((entry) => entry.id === id ? alert : entry));
      onAcknowledged();
    } catch (failure) {
      setError(failure.message);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <section className="panel" aria-labelledby="dashboard-alerts-title">
      <div className="toolbar wrap">
        <h2 className="panel-title" id="dashboard-alerts-title">Recent emergency alerts</h2>
        <Link to="/alerts">View all alerts</Link>
      </div>
      {error && <p className="error" role="alert">{error}</p>}
      {alerts?.length === 0 && <p className="muted">No emergency alerts match these filters.</p>}
      <div className="alerts-list">
        {alerts?.map((alert) => (
          <AlertCard key={alert.id} alert={alert} titleLevel="h3" busyId={busyId}
            canAcknowledge={can(user, 'alerts.acknowledge')} acknowledge={acknowledge} />
        ))}
      </div>
    </section>
  );
}
