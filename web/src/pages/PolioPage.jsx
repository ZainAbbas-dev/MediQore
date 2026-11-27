import { useState } from 'react';
import { Link } from 'react-router-dom';
import { ChildAnalyticsControls, ChildLoadStatus, ChildPagination } from '../components/ChildAnalyticsControls';
import { childAnalyticsQuery, useChildAnalytics } from '../components/ChildAnalyticsData';

const STATUS = {
  all_vaccinated: 'All vaccinated', partially_covered: 'Partially covered', refusal: 'Refusal',
  no_eligible_child: 'No eligible child', not_available: 'Not available',
};
const REFUSAL_REASON = { religious_concern: 'Religious concern', misinformation: 'Misinformation', past_reaction: 'Past reaction' };

function ProgressByArea({ areas }) {
  if (!areas.length) return null;
  return (
    <section className="panel" aria-labelledby="polio-areas">
      <h2 className="panel-title" id="polio-areas">Progress by area</h2>
      <div className="table-scroll">
        <table>
          <thead>
            <tr>
              <th scope="col">Area</th><th scope="col">Households visited</th><th scope="col">Children vaccinated</th>
              <th scope="col">All vaccinated</th><th scope="col">Partially covered</th><th scope="col">Refusal households</th>
              <th scope="col">Recorded refusals</th><th scope="col">Not available</th><th scope="col">No eligible child</th>
              <th scope="col">No OPV dose recorded</th>
            </tr>
          </thead>
          <tbody>
            {areas.map((area) => (
              <tr key={area.areaId}>
                <th scope="row">{area.areaName}</th><td>{area.householdsVisited}</td>
                <td>{area.childrenVaccinated} of {area.childrenEligible}</td><td>{area.allVaccinatedHouseholds}</td>
                <td>{area.partialHouseholds}</td><td>{area.refusalHouseholds}</td><td>{area.refusals}</td>
                <td>{area.notAvailableHouseholds}</td><td>{area.noEligibleHouseholds}</td><td>{area.noOpv}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function CampaignVisits({ data, onPage }) {
  if (!data.households.length) {
    return (
      <>
        <p className="muted">{data.total ? 'No household records on this page.' : 'No campaign household records match these filters.'}</p>
        <ChildPagination data={data} onPage={onPage} />
      </>
    );
  }
  return (
    <>
      <div className="table-scroll">
        <table>
          <thead>
            <tr>
              <th scope="col">Household</th><th scope="col">Area</th><th scope="col">Round</th><th scope="col">Last visit</th>
              <th scope="col">Status</th><th scope="col">Children vaccinated</th><th scope="col">Refusals</th>
              <th scope="col">Open revisit</th>
            </tr>
          </thead>
          <tbody>
            {data.households.map((visit) => (
              <tr key={visit.id}>
                <th scope="row">{visit.householdNumber || visit.village || '—'}</th>
                <td>{visit.areaName}{visit.householdNumber && visit.village && <div className="muted">{visit.village}</div>}</td>
                <td>{visit.roundName}</td><td className="nowrap">{visit.visitedOn}</td><td>{STATUS[visit.status] ?? visit.status}</td>
                <td>{visit.childrenVaccinated} of {visit.childrenEligible}</td>
                <td>{visit.refusals || '—'}{visit.refusalReasons?.map((reason) => <div key={reason}>{REFUSAL_REASON[reason] ?? reason}</div>)}</td>
                <td className="nowrap">{visit.nextRevisitOn || '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <ChildPagination data={data} onPage={onPage} />
    </>
  );
}

export default function PolioPage() {
  const [selection, setSelection] = useState({ districtId: '', areaId: '', startDate: '', endDate: '', roundId: '' });
  const [page, setPage] = useState(1);
  const optionState = useChildAnalytics('filters');
  const progress = useChildAnalytics('polio', { ...selection, page: page > 1 ? page : '' });
  const summary = progress.data?.summary;
  const childQuery = childAnalyticsQuery({
    districtId: selection.districtId, areaId: selection.areaId, endDate: selection.endDate, followUp: 'no-opv',
  });
  const setFilters = (update) => {
    setSelection((current) => ({ ...current, ...update }));
    setPage(1);
  };

  return (
    <>
      <div className="page-header">
        <div><h1>Polio campaigns</h1><p className="page-subtitle">OPV campaign progress and household follow-up.</p></div>
        <ChildAnalyticsControls selection={selection} options={optionState.data} onChange={setFilters}>
          <label className="field">
            Campaign round
            <select value={selection.roundId} onChange={(event) => setFilters({ roundId: event.target.value })}>
              <option value="">All rounds</option>
              {optionState.data?.rounds.map((round) => (
                <option key={round.id} value={round.id}>{round.name} ({round.startsOn} – {round.endsOn})</option>
              ))}
            </select>
          </label>
        </ChildAnalyticsControls>
      </div>
      {optionState.error && <p className="error" role="alert">{optionState.error}</p>}
      <ChildLoadStatus {...progress} />
      <section className="cards" aria-label="Campaign summary">
        <div className="card"><div className="card-label">Households visited</div><div className="card-value">{summary?.householdsVisited ?? '—'}</div></div>
        <div className="card">
          <div className="card-label">Children vaccinated</div>
          <div className="card-value">{summary?.childrenVaccinated ?? '—'}{summary && <span className="of">of {summary.childrenEligible}</span>}</div>
        </div>
        <div className="card"><div className="card-label">Recorded refusals</div><div className="card-value">{summary?.refusals ?? '—'}</div></div>
        <div className="card">
          <div className="card-label">{selection.roundId && !selection.areaId ? 'No OPV dose recorded' : <Link to={`/children${childQuery}`}>No OPV dose recorded</Link>}</div>
          <div className="card-value">{summary?.noOpv ?? '—'}</div>
        </div>
      </section>
      {progress.data && (
        <>
          <ProgressByArea areas={progress.data.areas} />
          <section className="panel" aria-labelledby="polio-visits">
            <h2 className="panel-title" id="polio-visits">Campaign household records</h2>
            <p className="muted">Latest synced visit per household and round in the selected period. No-OPV counts include routine and campaign OPV through {progress.data.asOf}.</p>
            <CampaignVisits data={progress.data} onPage={setPage} />
          </section>
        </>
      )}
    </>
  );
}
