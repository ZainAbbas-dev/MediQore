import { useEffect, useState } from 'react';
import { apiRequest } from '../api/client';
import { useAuth } from '../auth/context';
import AreaMap from '../components/AreaMap';

const NO_HOUSEHOLDS = [];

// Dashboard home (M10). For Phase 0 it shows the households synced from the
// LHW app in the user's areas: the end of the end-to-end check (P0-6). Cards,
// filters and auto-refresh are Module 10 work in Phase 1.
export default function DashboardPage() {
  const { token, logout } = useAuth();
  const [households, setHouseholds] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    apiRequest('/households', { token })
      .then((data) => {
        if (!cancelled) setHouseholds(data.households);
      })
      .catch((err) => {
        if (cancelled) return;
        if (err.status === 401) logout();
        else setError(err.message);
      });
    return () => {
      cancelled = true;
    };
  }, [token, logout]);

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
