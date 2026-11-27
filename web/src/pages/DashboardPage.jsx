// Dashboard home (M10 FE-1, Phase 1 base, final design screen 20). Cards for
// registered women, visits this week, LHWs synced today and sync conflicts to
// review; the households with GPS on a map; and each LHW's activity: last sync,
// women registered, visits, last visit and last sign-in, with an LHW who has not
// synced for days highlighted. Everything follows the filters (district, tehsil, Union
// Council, LHW and period), and the page refreshes itself
// every five minutes or on Reload. Supervisors see only their areas; the API
// scopes every list.
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { can, useAuth } from '../auth/context';
import AreaMap from '../components/AreaMap';
import ChildCoverageTable from '../components/ChildCoverageTable';
import DashboardAlerts from '../components/DashboardAlerts';
import MaternalDashboard from '../components/MaternalDashboard';
import { InactivityStatus } from './ActivityPage';
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
const EMPTY_FILTERS = { districtId: '', tehsilId: '', unionCouncilId: '', lhwId: '', days: '' };
const NO_OPTIONS = { districts: [], tehsils: [], unionCouncils: [], lhws: [] };

function queryString(values) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(values)) if (value) params.set(key, value);
  const text = params.toString();
  return text ? `?${text}` : '';
}

export default function DashboardPage() {
  const { request, user } = useAuth();
  const [filters, setFilters] = useState(EMPTY_FILTERS);
  const [options, setOptions] = useState(NO_OPTIONS);
  const [summary, setSummary] = useState(null);
  const [households, setHouseholds] = useState(null);
  const [activity, setActivity] = useState(null);
  const [maternal, setMaternal] = useState(null);
  const pageRequest = useRef(0);
  const [hotspots, setHotspots] = useState([]);
  const [coverage, setCoverage] = useState(null);
  const [inactivity, setInactivity] = useState(null);
  const [mapLayer, setMapLayer] = useState('households');
  const [facilityMarkers, setFacilityMarkers] = useState(true);
  const [updatedAt, setUpdatedAt] = useState(null);
  const [error, setError] = useState(null);
  const [refreshes, setRefreshes] = useState(0);

  useEffect(() => {
    request('/dashboard/filters')
      .then((data) => setOptions({ ...NO_OPTIONS, ...data }))
      .catch(() => setOptions(NO_OPTIONS)); // the page works without filters
  }, [request]);

  // Each part loads on its own, so one failure does not hide the rest.
  useEffect(() => {
    let cancelled = false;
    pageRequest.current++;
    const query = queryString(filters);
    Promise.allSettled([
      request(`/dashboard/summary${query}`),
      request(`/households${query}`),
      request(`/dashboard/lhw-activity${query}`),
      request(`/dashboard/maternal${query}`),
      request(`/child-analytics/hotspots${query}`),
      request('/inactivity'),
      request(`/child-analytics/coverage${query}`),
    ]).then(([summaryResult, householdsResult, activityResult, maternalResult, hotspotResult, inactivityResult, coverageResult]) => {
      if (cancelled) return;
      setSummary(summaryResult.status === 'fulfilled' ? summaryResult.value : null);
      setHouseholds(householdsResult.status === 'fulfilled' ? householdsResult.value.households : null);
      setActivity(activityResult.status === 'fulfilled' ? activityResult.value.lhws : null);
      setMaternal(maternalResult.status === 'fulfilled' ? maternalResult.value : null);
      setHotspots(hotspotResult.status === 'fulfilled' ? hotspotResult.value.households : []);
      setInactivity(inactivityResult.status === 'fulfilled' ? inactivityResult.value : null);
      setCoverage(coverageResult.status === 'fulfilled' ? coverageResult.value : null);
      const failed = [summaryResult, householdsResult, activityResult, maternalResult, hotspotResult, inactivityResult, coverageResult]
        .find((result) => result.status === 'rejected');
      setError(failed ? failed.reason.message : null);
      if (summaryResult.status === 'fulfilled' && householdsResult.status === 'fulfilled' && activityResult.status === 'fulfilled') {
        setUpdatedAt(new Date());
      }
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

  // Each list keeps only the places inside the wider choices.
  const inside = useCallback(
    (item) =>
      (!filters.districtId || item.districtId === filters.districtId) && (!filters.tehsilId || item.tehsilId === filters.tehsilId),
    [filters.districtId, filters.tehsilId],
  );
  const tehsils = useMemo(
    () => options.tehsils.filter((t) => !filters.districtId || t.districtId === filters.districtId),
    [options, filters.districtId],
  );
  const unionCouncils = useMemo(() => options.unionCouncils.filter(inside), [options, inside]);
  const lhws = useMemo(
    () =>
      options.lhws.filter(
        (l) => inside(l) && (!filters.unionCouncilId || l.unionCouncilId === filters.unionCouncilId),
      ),
    [options, inside, filters.unionCouncilId],
  );

  // A narrower place clears the choices that are no longer inside it.
  const setFilter = (field) => (event) => {
    const value = event.target.value;
    setFilters((current) => {
      const next = { ...current, [field]: value };
      if (field === 'districtId') next.tehsilId = '';
      if (field === 'districtId' || field === 'tehsilId') {
        next.unionCouncilId = '';
        next.lhwId = '';
      }
      if (field === 'unionCouncilId') next.lhwId = '';
      return next;
    });
  };
  async function changeHighRiskPage(offset) {
    const generation = ++pageRequest.current;
    try {
      const data = await request(`/dashboard/maternal${queryString({ ...filters, offset })}`);
      if (generation !== pageRequest.current) return;
      setMaternal(data);
      setError(null);
    } catch (error) {
      if (generation === pageRequest.current) setError(error.message);
    }
  }

  const filtered = Object.values(filters).some(Boolean);
  const mapped = households?.filter((h) => h.latitude !== null && h.longitude !== null).length;
  const now = updatedAt ?? new Date();
  const activityStatus = new Map((inactivity?.lhws ?? []).map((row) => [row.id, row]));
  const recordsOnMap = mapLayer === 'highRisk'
    ? households?.filter((h) => h.riskLevel === 'red')
    : mapLayer === 'coverage'
      ? hotspots.filter((h) => h.coverageGaps > 0).map((h) => ({ ...h, mapLabel: `${h.coverageGaps} children with coverage gaps` }))
      : mapLayer === 'nutrition'
        ? hotspots.filter((h) => h.sam || h.mam || h.underweight || h.stunting).map((h) => ({
          ...h, mapLabel: `SAM ${h.sam} · MAM ${h.mam} · Underweight ${h.underweight ?? 0} · Stunting ${h.stunting ?? 0}`,
        }))
        : households;

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
            Tehsil
            <select value={filters.tehsilId} onChange={setFilter('tehsilId')}>
              <option value="">All</option>
              {tehsils.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
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
        <div className={maternal?.riskDistribution.red ? 'card attention' : 'card'}>
          <div className="card-label">High-risk pregnancies</div>
          <div className="card-value">{maternal?.riskDistribution.red ?? '–'}</div>
        </div>
        <div className={maternal?.unacknowledgedAlerts ? 'card attention' : 'card'}>
          <div className="card-label">
            {can(user, 'alerts.view') ? <Link to="/alerts">Unacknowledged alerts</Link> : 'Unacknowledged alerts'}
          </div>
          <div className="card-value">{maternal?.unacknowledgedAlerts ?? '–'}</div>
        </div>
        <div className={summary?.pendingConflicts ? 'card attention' : 'card'}>
          <div className="card-label">
            {can(user, 'conflicts.resolve') ? <Link to="/conflicts">Sync conflicts to review</Link> : 'Sync conflicts to review'}
          </div>
          <div className="card-value">{summary?.pendingConflicts ?? '–'}</div>
        </div>
      </section>

      {can(user, 'alerts.view') && (
        <DashboardAlerts
          key={queryString(filters)}
          query={queryString({ emergencyOnly: true, limit: 3, ...filters })}
          refreshes={refreshes}
          onAcknowledged={() => setRefreshes((count) => count + 1)}
        />
      )}
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
        <div className="header-controls map-controls">
          <label className="field">
            Map layer
            <select value={mapLayer} onChange={(event) => setMapLayer(event.target.value)}>
              <option value="households">Household risk</option>
              <option value="highRisk">High-risk clusters</option>
              <option value="coverage">Immunisation coverage gaps</option>
              <option value="nutrition">Malnutrition hotspots</option>
            </select>
          </label>
          <label className="checkbox-label">
            <input type="checkbox" checked={facilityMarkers} onChange={(event) => setFacilityMarkers(event.target.checked)} />
            Referral facilities
          </label>
        </div>
        <AreaMap households={recordsOnMap ?? NO_HOUSEHOLDS} facilities={facilityMarkers ? maternal?.facilities : []} />
        {mapLayer !== 'households' && recordsOnMap?.length === 0 && <p className="muted">No locations match this layer.</p>}
        <p className="muted">
          {households && households.length === 0
            ? filtered
              ? 'No households match these filters.'
              : 'No households have been synced yet.'
            : 'Risk markers use the latest assessment for each active pregnancy.'}
        </p>
      </section>

      <MaternalDashboard maternal={maternal} now={now} onPage={changeHighRiskPage} />
      {coverage && (
        <section className="panel" aria-labelledby="coverage-title">
          <h2 className="panel-title" id="coverage-title">Immunisation coverage</h2>
          <p className="muted">Penta-1 zero-dose: {coverage.zeroDose} · <Link to="/children">View child register</Link></p>
          <ChildCoverageTable antigens={coverage.antigens} threshold={coverage.coverageThreshold} />
        </section>
      )}

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
                  <th>Referrals completed</th>
                  <th>Missed ANC</th>
                  <th>Inactivity</th>
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
                      <td>{lhw.referralsCompleted ?? '–'}</td>
                      <td>{lhw.missedAnc ?? '–'}</td>
                      <td><InactivityStatus inactivity={activityStatus.get(lhw.id)?.inactivity} lastSyncAt={activityStatus.get(lhw.id)?.lastSyncAt} /></td>
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
