// Dashboard home (M10 FE-1, Phase 1 base, final design screen 20). Cards for
// registered women, visits this week, LHWs synced today and sync conflicts to
// review; the households with GPS on a map; and each LHW's activity: last sync,
// women registered, visits, last visit and last sign-in, with an LHW who has not
// synced for days highlighted. Everything follows the filters (district, Union
// Council, LHW; the period applies to the map), and the page refreshes itself
// every five minutes or on Reload. Supervisors see only their areas; the API
// scopes every list.
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../auth/context';
import AreaMap from '../components/AreaMap';
import { STALE_AFTER_DAYS, clock, formatWhen, isStale } from '../format';

const NO_HOUSEHOLDS = [];
// GET /households answers at most this many by default; the map title then says so.
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
    const { districtId, unionCouncilId, lhwId } = filters;
    const place = queryString({ districtId, unionCouncilId, lhwId });
    Promise.allSettled([
      request(`/dashboard/summary${place}`),
      request(`/households${queryString(filters)}`),
      request(`/dashboard/lhw-activity${place}`),
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
  const mapped = households?.filter((h) => h.latitude !== null && h.longitude !== null).length;
  const now = updatedAt ?? new Date();

  return (
    <>
      <div className="page-header">
        <div>
          <h1>Dashboard</h1>
          <p className="page-subtitle">
            Refreshes every 5 minutes{updatedAt && ` · last refresh ${clock(updatedAt)}`}
          </p>
        </div>
        <div className="header-controls" role="group" aria-label="Filters">
          <label className="field">
            District
            <select value={filters.districtId} onChange={setFilter('districtId')}>
              <option value="">All</option>
              {options.districts.map((d) => (
                <option key={d.id} value={d.id}>
                  {d.name}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            Union Council
            <select value={filters.unionCouncilId} onChange={setFilter('unionCouncilId')}>
              <option value="">All</option>
              {unionCouncils.map((uc) => (
                <option key={uc.id} value={uc.id}>
                  {uc.name}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            LHW
            <select value={filters.lhwId} onChange={setFilter('lhwId')}>
              <option value="">All</option>
              {lhws.map((l) => (
                <option key={l.id} value={l.id}>
                  {l.lhwCode} · {l.fullName}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            Period
            <select value={filters.days} onChange={setFilter('days')}>
              {PERIODS.map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </label>
          {filtered && (
            <button type="button" className="secondary" onClick={() => setFilters(EMPTY_FILTERS)}>
              Clear filters
            </button>
          )}
          <button type="button" onClick={() => setRefreshes((n) => n + 1)}>
            Reload
          </button>
        </div>
      </div>
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}

      <section className="cards" aria-label="Summary">
        <div className="card">
          <div className="card-label">Registered women</div>
          <div className="card-value">{summary?.registeredWomen ?? '–'}</div>
        </div>
        <div className="card">
          <div className="card-label">Visits this week</div>
          <div className="card-value">{summary?.visitsThisWeek ?? '–'}</div>
        </div>
        <div className="card">
          <div className="card-label">LHWs synced today</div>
          <div className="card-value">
            {summary ? summary.lhwsSyncedToday : '–'}
            {summary && <span className="of">of {summary.lhws}</span>}
          </div>
        </div>
        <div className={summary?.pendingConflicts ? 'card attention' : 'card'}>
          <div className="card-label">
            <Link to="/conflicts">Sync conflicts to review</Link>
          </div>
          <div className="card-value">{summary?.pendingConflicts ?? '–'}</div>
        </div>
      </section>

      <section className="panel" aria-labelledby="map-title">
        <h2 className="panel-title" id="map-title">
          Households with GPS
          {households && (
            <span className="muted">
              {' '}
              · {mapped}
              {households.length >= HOUSEHOLD_LIMIT ? ' of the latest 200' : ''}
            </span>
          )}
        </h2>
        <AreaMap households={households ?? NO_HOUSEHOLDS} />
        <p className="muted">
          {households && households.length === 0
            ? filtered
              ? 'No households match these filters.'
              : 'No households have been synced yet.'
            : 'The period counts from when the server received each household.'}
        </p>
      </section>

      <section className="panel" aria-labelledby="activity-title">
        <h2 className="panel-title" id="activity-title">
          LHW activity
        </h2>
        {activity && activity.length === 0 && <p className="muted">No LHWs in these areas.</p>}
        {activity && activity.length > 0 && (
          <div className="table-scroll">
            <table className="lhw-activity">
              <thead>
                <tr>
                  <th>LHW</th>
                  <th className="col-place">Area</th>
                  <th>Last sync</th>
                  <th>Women</th>
                  <th>Visits this week</th>
                  <th>Visits in total</th>
                  <th>Last visit</th>
                  <th>Last sign-in</th>
                </tr>
              </thead>
              <tbody>
                {activity.map((lhw) => {
                  const stale = lhw.isActive && isStale(lhw.lastSyncAt, now);
                  return (
                    <tr key={lhw.id} className={stale ? 'stale' : undefined}>
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
                      <td className={stale ? 'nowrap stale-text' : 'nowrap'}>{formatWhen(lhw.lastSyncAt, now) ?? 'Never'}</td>
                      <td>{lhw.womenRegistered}</td>
                      <td>{lhw.visitsThisWeek}</td>
                      <td>{lhw.visitsTotal}</td>
                      <td className="nowrap">{formatWhen(lhw.lastVisitAt, now, { withTime: false }) ?? '–'}</td>
                      <td className="nowrap">{formatWhen(lhw.lastLoginAt, now) ?? 'Never'}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
        {activity && activity.some((l) => l.isActive && isStale(l.lastSyncAt, now)) && (
          <p className="muted">Highlighted: no sync for {STALE_AFTER_DAYS} days or more.</p>
        )}
      </section>
    </>
  );
}
