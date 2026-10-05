// Dashboard home (M10 FE-1, Phase 1 base). Counts for the viewer's areas
// (registered women, visits this week, sync conflicts to review, households),
// the households on a map and in a table, and each LHW's activity: visits,
// registrations, last sync and last sign-in. The map, table and LHW activity
// can be filtered by district, Union Council, LHW and time period, and the page
// refreshes itself every five minutes or on Reload. Supervisors see only their
// areas; the API scopes every list.
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../auth/context';
import AreaMap from '../components/AreaMap';

const NO_HOUSEHOLDS = [];
// GET /households answers at most this many by default; the card then says "200+".
const HOUSEHOLD_LIMIT = 200;
const REFRESH_EVERY_MS = 5 * 60 * 1000;
const PERIODS = [
  ['', 'Any time'],
  ['7', 'Last 7 days'],
  ['30', 'Last 30 days'],
  ['90', 'Last 90 days'],
];
const EMPTY_FILTERS = { districtId: '', unionCouncilId: '', lhwId: '', days: '' };
const NO_OPTIONS = { districts: [], unionCouncils: [], lhws: [] };

const formatTime = (value) => (value ? new Date(value).toLocaleString() : '–');
const formatDate = (value) => (value ? new Date(value).toLocaleDateString() : '–');

function queryString(values) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(values)) if (value) params.set(key, value);
  const text = params.toString();
  return text ? `?${text}` : '';
}

export default function DashboardPage() {
  const { request } = useAuth();
  const [filters, setFilters] = useState(EMPTY_FILTERS);
  const [options, setOptions] = useState(NO_OPTIONS);
  const [summary, setSummary] = useState(null);
  const [households, setHouseholds] = useState(null);
  const [activity, setActivity] = useState(null);
  const [updatedAt, setUpdatedAt] = useState(null);
  const [error, setError] = useState(null);
  const [refreshes, setRefreshes] = useState(0);

  useEffect(() => {
    request('/dashboard/filters')
      .then(setOptions)
      .catch(() => setOptions(NO_OPTIONS)); // the page works without filters
  }, [request]);

  // Each part loads on its own, so one failure does not hide the rest.
  useEffect(() => {
    let cancelled = false;
    const { districtId, unionCouncilId } = filters;
    Promise.allSettled([
      request('/dashboard/summary'),
      request(`/households${queryString(filters)}`),
      request(`/dashboard/lhw-activity${queryString({ districtId, unionCouncilId })}`),
    ]).then(([summaryResult, householdsResult, activityResult]) => {
      if (cancelled) return;
      if (summaryResult.status === 'fulfilled') setSummary(summaryResult.value);
      if (householdsResult.status === 'fulfilled') setHouseholds(householdsResult.value.households);
      if (activityResult.status === 'fulfilled') setActivity(activityResult.value.lhws);
      const failed = [summaryResult, householdsResult, activityResult].find((r) => r.status === 'rejected');
      setError(failed ? failed.reason.message : null);
      setUpdatedAt(new Date());
    });
    return () => {
      cancelled = true;
    };
  }, [request, filters, refreshes]);

  // M10 FE-1: the map and counts refresh automatically every five minutes.
  useEffect(() => {
    const timer = setInterval(() => setRefreshes((n) => n + 1), REFRESH_EVERY_MS);
    return () => clearInterval(timer);
  }, []);

  const unionCouncils = useMemo(
    () => options.unionCouncils.filter((uc) => !filters.districtId || uc.districtId === filters.districtId),
    [options, filters.districtId],
  );
  const lhws = useMemo(
    () =>
      options.lhws.filter(
        (l) => (!filters.districtId || l.districtId === filters.districtId) && (!filters.unionCouncilId || l.unionCouncilId === filters.unionCouncilId),
      ),
    [options, filters.districtId, filters.unionCouncilId],
  );

  // A narrower place clears the choices that are no longer inside it.
  const setFilter = (field) => (event) => {
    const value = event.target.value;
    setFilters((current) => {
      const next = { ...current, [field]: value };
      if (field === 'districtId') {
        next.unionCouncilId = '';
        next.lhwId = '';
      }
      if (field === 'unionCouncilId') next.lhwId = '';
      return next;
    });
  };
  const filtered = Object.values(filters).some(Boolean);

  return (
    <>
      <div className="page-header">
        <h1>Dashboard</h1>
        <div className="refresh">
          {updatedAt && <span className="muted">Updated {updatedAt.toLocaleTimeString()}; refreshes every 5 minutes</span>}
          <button type="button" className="secondary" onClick={() => setRefreshes((n) => n + 1)}>
            Reload
          </button>
        </div>
      </div>
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
          <div className="card-value">
            {households ? `${households.length}${households.length >= HOUSEHOLD_LIMIT ? '+' : ''}` : '–'}
          </div>
          <div className="card-label">Registered households{filtered ? ' (filtered)' : ''}</div>
        </div>
      </section>

      <div className="toolbar wrap" role="group" aria-label="Filters">
        <label htmlFor="filter-district">District</label>
        <select id="filter-district" value={filters.districtId} onChange={setFilter('districtId')}>
          <option value="">All</option>
          {options.districts.map((d) => (
            <option key={d.id} value={d.id}>
              {d.name}
            </option>
          ))}
        </select>
        <label htmlFor="filter-uc">Union Council</label>
        <select id="filter-uc" value={filters.unionCouncilId} onChange={setFilter('unionCouncilId')}>
          <option value="">All</option>
          {unionCouncils.map((uc) => (
            <option key={uc.id} value={uc.id}>
              {uc.name}
            </option>
          ))}
        </select>
        <label htmlFor="filter-lhw">LHW</label>
        <select id="filter-lhw" value={filters.lhwId} onChange={setFilter('lhwId')}>
          <option value="">All</option>
          {lhws.map((l) => (
            <option key={l.id} value={l.id}>
              {l.lhwCode} · {l.fullName}
            </option>
          ))}
        </select>
        <label htmlFor="filter-period">Period</label>
        <select id="filter-period" value={filters.days} onChange={setFilter('days')}>
          {PERIODS.map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
        {filtered && (
          <button type="button" className="secondary" onClick={() => setFilters(EMPTY_FILTERS)}>
            Clear filters
          </button>
        )}
      </div>
      <p className="muted">
        The filters apply to the map and the households; district and Union Council also to LHW activity. The period counts
        when the server received each household.
      </p>

      <AreaMap households={households ?? NO_HOUSEHOLDS} />

      <h2>LHW activity</h2>
      {activity && activity.length === 0 && <p className="muted">No LHWs in these areas.</p>}
      {activity && activity.length > 0 && (
        <div className="table-scroll">
          <table className="lhw-activity">
            <thead>
              <tr>
                <th>LHW</th>
                <th className="col-place">Area</th>
                <th>Visits this week</th>
                <th>Visits in total</th>
                <th>Women registered</th>
                <th>Last visit</th>
                <th>Last sync</th>
                <th>Last sign-in</th>
              </tr>
            </thead>
            <tbody>
              {activity.map((lhw) => (
                <tr key={lhw.id}>
                  <td className="nowrap">
                    {lhw.lhwCode}
                    {!lhw.isActive && <span className="badge off">deactivated</span>}
                    <div className="muted">{lhw.fullName}</div>
                  </td>
                  <td>
                    {lhw.area}
                    <div className="muted">
                      {lhw.unionCouncil}, {lhw.district}
                    </div>
                  </td>
                  <td>{lhw.visitsThisWeek}</td>
                  <td>{lhw.visitsTotal}</td>
                  <td>{lhw.womenRegistered}</td>
                  <td className="nowrap">{formatDate(lhw.lastVisitAt)}</td>
                  <td className="nowrap">{formatTime(lhw.lastSyncAt)}</td>
                  <td className="nowrap">{lhw.lastLoginAt ? formatTime(lhw.lastLoginAt) : 'Never'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <h2>Recently synced households</h2>
      {households && households.length === 0 && (
        <p className="muted">{filtered ? 'No households match these filters.' : 'No households have been synced yet.'}</p>
      )}
      {households && households.length > 0 && (
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Household</th>
                <th>Village</th>
                <th>Area</th>
                <th>Registered by</th>
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
                  <td>{h.registeredBy || '–'}</td>
                  <td>{formatTime(h.syncedAt)}</td>
                  <td>{h.serverSeq}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}
