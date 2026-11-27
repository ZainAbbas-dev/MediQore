import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { ChildAnalyticsControls, ChildLoadStatus, ChildPagination } from '../components/ChildAnalyticsControls';
import { useChildAnalytics } from '../components/ChildAnalyticsData';
import ChildCoverageTable from '../components/ChildCoverageTable';

const CLASSIFICATION = { sam: 'SAM', mam: 'MAM', normal: 'Normal' };

function ChildRegister({ data, onPage }) {
  if (!data.children.length) {
    return (
      <>
        <p className="muted">{data.total ? 'No children on this page.' : 'No children match these filters.'}</p>
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
              <th scope="col">Child</th><th scope="col">Date of birth</th><th scope="col">Area</th>
              <th scope="col">Immunisation follow-up</th><th scope="col">Latest nutrition screening</th>
            </tr>
          </thead>
          <tbody>
            {data.children.map((child) => {
              const n = child.latestScreening;
              return (
                <tr key={child.id}>
                  <th scope="row">{child.name}<div className="muted">{child.sex}{child.status === 'deceased' && ' · Deceased'}</div></th>
                  <td className="nowrap">{child.dateOfBirth}</td>
                  <td>
                    {child.areaName}
                    {(child.village || child.householdNumber) && (
                      <div className="muted">{[child.village, child.householdNumber].filter(Boolean).join(' · ')}</div>
                    )}
                  </td>
                  <td>
                    {child.zeroDose && <div>WHO zero-dose</div>}
                    {child.noOpv && <div>No OPV dose recorded</div>}
                    {child.coverageGap && <div>Incomplete routine series</div>}
                    {!child.zeroDose && !child.noOpv && !child.coverageGap && '—'}
                  </td>
                  <td>
                    {n ? (
                      <>
                        <span className="nowrap">{n.screenedOn}</span>
                        {n.malnutritionClass && <div>{CLASSIFICATION[n.malnutritionClass]}</div>}
                        {n.underweight && <div>Underweight</div>}
                        {n.stunting && <div>Stunting</div>}
                      </>
                    ) : '—'}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <ChildPagination data={data} onPage={onPage} />
    </>
  );
}

function CoverageByArea({ data }) {
  const [preferredAntigen, setPreferredAntigen] = useState('Penta');
  const activeAntigen = data.antigens.find((entry) => entry.antigen === preferredAntigen)?.antigen ?? data.antigens[0]?.antigen;
  if (!data.areas.length || !activeAntigen) return null;

  return (
    <section className="panel" aria-labelledby="child-area-coverage">
      <div className="page-header">
        <h2 className="panel-title" id="child-area-coverage">Coverage by area</h2>
        <label className="field">
          Antigen
          <select value={activeAntigen} onChange={(event) => setPreferredAntigen(event.target.value)}>
            {data.antigens.map(({ antigen }) => <option key={antigen}>{antigen}</option>)}
          </select>
        </label>
      </div>
      <div className="table-scroll">
        <table>
          <thead>
            <tr>
              <th scope="col">Area</th><th scope="col">Fully vaccinated</th><th scope="col">Coverage</th>
              <th scope="col">WHO zero-dose</th><th scope="col">No OPV dose recorded</th>
            </tr>
          </thead>
          <tbody>
            {data.areas.map((area) => {
              const entry = area.antigens.find(({ antigen }) => antigen === activeAntigen);
              return (
                <tr key={area.areaId}>
                  <th scope="row">{area.areaName}</th>
                  <td>{entry?.eligible ? `${entry.fullyVaccinated} of ${entry.eligible}` : '—'}</td>
                  <td>
                    {entry?.percentage != null ? `${entry.percentage}%` : '—'}
                    {entry?.lowCoverage && <div className="muted">Below {data.coverageThreshold}%</div>}
                  </td>
                  <td>{area.zeroDose}</td><td>{area.noOpv}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </section>
  );
}

export default function ChildrenPage() {
  const [params] = useSearchParams();
  const [selection, setSelection] = useState(() => ({
    districtId: params.get('districtId') ?? '', areaId: params.get('areaId') ?? '', endDate: params.get('endDate') ?? '',
  }));
  const [followUp, setFollowUp] = useState(() => params.get('followUp') ?? '');
  const [page, setPage] = useState(1);
  const optionState = useChildAnalytics('filters');
  const register = useChildAnalytics('children', { ...selection, followUp, page: page > 1 ? page : '' });
  const coverage = useChildAnalytics('coverage', selection);
  const setFilters = (update) => {
    setSelection((current) => ({ ...current, ...update }));
    setPage(1);
  };

  return (
    <>
      <div className="page-header">
        <div><h1>Children</h1><p className="page-subtitle">Child register, immunisation coverage and nutrition screenings.</p></div>
        <ChildAnalyticsControls selection={selection} options={optionState.data} onChange={setFilters} periodStart={false} />
      </div>
      {optionState.error && <p className="error" role="alert">{optionState.error}</p>}
      <section className="cards" aria-label="Child immunisation follow-up">
        {[
          ['Registered children under five', coverage.data?.totalChildren],
          ['WHO zero-dose', coverage.data?.zeroDose],
          ['No OPV dose recorded', coverage.data?.noOpv],
        ].map(([label, value]) => (
          <div key={label} className="card"><div className="card-label">{label}</div><div className="card-value">{value ?? '—'}</div></div>
        ))}
      </section>
      <section className="panel" aria-labelledby="child-coverage">
        <h2 className="panel-title" id="child-coverage">Routine immunisation coverage</h2>
        <ChildLoadStatus {...coverage} />
        {coverage.data && (
          <>
            <p className="muted">
              As of {coverage.data.asOf} · EPI {coverage.data.scheduleVersion}
              {coverage.data.reviewStatus === 'pending_clinical_review' && ' · Pending clinical review'}
            </p>
            <p className="muted">
              For each antigen, coverage includes children under two who have reached the scheduled age for the final routine dose.
              WHO zero-dose counts children under five past the due age for Penta-1 without a recorded Penta-1 dose.
            </p>
            {coverage.data.antigens.length ? (
              <ChildCoverageTable antigens={coverage.data.antigens} threshold={coverage.data.coverageThreshold} />
            ) : <p className="muted">No coverage data for these filters.</p>}
          </>
        )}
      </section>
      {coverage.data && <CoverageByArea data={coverage.data} />}
      <section className="panel" aria-labelledby="child-register">
        <div className="page-header">
          <h2 className="panel-title" id="child-register">Registered children</h2>
          <label className="field">
            Follow-up
            <select value={followUp} onChange={(event) => { setFollowUp(event.target.value); setPage(1); }}>
              <option value="">All children</option>
              <option value="zero-dose">WHO zero-dose</option>
              <option value="no-opv">No OPV dose recorded</option>
            </select>
          </label>
        </div>
        <ChildLoadStatus {...register} />
        {register.data && <ChildRegister data={register.data} onPage={setPage} />}
      </section>
    </>
  );
}
