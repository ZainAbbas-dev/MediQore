import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../auth/context';
import AreaMap from '../components/AreaMap';

const NO_HOUSEHOLDS = [];

// Dashboard home (M10). It shows the households synced from the LHW app in the
// user's areas (the end of the P0-6 end-to-end check) and the counts of
// GET /dashboard/summary: registered women (M2), visits this week and visits
// waiting in the sync conflict queue (M3, M10 FE-1). The other cards, filters
// and auto-refresh are Module 10 work in Phase 1.
export default function DashboardPage() {
  const { request } = useAuth();
  const [households, setHouseholds] = useState(null);
  const [summary, setSummary] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    Promise.all([request('/households'), request('/dashboard/summary')])
      .then(([householdData, summaryData]) => {
        if (cancelled) return;
        setHouseholds(householdData.households);
        setSummary(summaryData);
      })
      .catch((err) => {
        if (!cancelled) setError(err.message);
      });
    return () => {
      cancelled = true;
    };
  }, [request]);

  return (
    <>
      <h1>Dashboard</h1>
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      <section className="cards">
        <div className="card">
          <div className="card-value">{summary?.registeredWomen ?? '–'}</div>
          <div className="card-label">Registered women</div>
        </div>
        <div className="card">
          <div className="card-value">{summary?.visitsThisWeek ?? '–'}</div>
          <div className="card-label">Visits this week</div>
        </div>
        <div className={summary?.pendingConflicts ? 'card attention' : 'card'}>
          <div className="card-value">{summary?.pendingConflicts ?? '–'}</div>
          <div className="card-label">
            <Link to="/conflicts">Sync conflicts to review</Link>
          </div>
        </div>
        <div className="card">
          <div className="card-value">{households ? households.length : '–'}</div>
          <div className="card-label">Registered households</div>
        </div>
      </section>
      <AreaMap households={households ?? NO_HOUSEHOLDS} />
      <h2>Recently synced households</h2>
      {households && households.length === 0 && <p className="muted">No households have been synced yet.</p>}
      {households && households.length > 0 && (
        <table>
          <thead>
            <tr>
              <th>Household</th>
              <th>Village</th>
              <th>Area</th>
              <th>Synced</th>
              <th>Server no.</th>
            </tr>
          </thead>
          <tbody>
            {households.map((h) => (
              <tr key={h.id}>
                <td>{h.householdNumber || '–'}</td>
                <td>{h.village || '–'}</td>
                <td>{h.areaName}</td>
                <td>{new Date(h.syncedAt).toLocaleString()}</td>
                <td>{h.serverSeq}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </>
  );
}
