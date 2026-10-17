// M2 FE-1, FE-2, FE-3: registered women for supervisors and admins (M10 FE-1
// shows registered patients). A supervisor sees only their areas; the API
// scopes the list. Each row has the woman's pregnancy file in short, and how
// many visits have reached the server; her visits open with their vitals,
// blood sugar details and danger-sign answers (M3 FE-1).
import { useEffect, useState } from 'react';
import { useAuth } from '../auth/context';
import Dialog from '../components/Dialog';
import { formatWhen } from '../format';

// The six danger-sign questions of the visit (M3 FE-1), in the app's order.
const DANGER_SIGNS = [
  ['convulsions', 'Convulsions or fits'],
  ['severeHeadache', 'Severe headache'],
  ['blurredVision', 'Blurred vision'],
  ['severeAbdominalPain', 'Severe or upper abdominal pain'],
  ['fastBreathing', 'Fast or difficult breathing'],
  ['feverWithWeakness', 'Fever with weakness'],
];
const FETAL_MOVEMENT = { normal: 'Normal', reduced: 'Markedly reduced', absent: 'Absent' };
const ANAEMIA = { none: 'None', present: 'Some', severe: 'Severe' };
const SUGAR_SOURCE = { glucometer: 'glucometer', lab_report: 'lab report' };

const yesNo = (value) => (value ? 'Yes' : 'No');
const orDash = (value, unit = '') => (value === null || value === undefined ? '–' : `${value}${unit}`);

function bloodSugar(v) {
  if (v.bloodSugarMmolL === null) return 'Not tested';
  const typed = v.bloodSugarEnteredUnit === 'mg_dl' ? ', typed in mg/dL' : '';
  return `${v.bloodSugarMmolL} mmol/L (${SUGAR_SOURCE[v.bloodSugarSource] ?? v.bloodSugarSource}, ${v.bloodSugarMeasuredOn}${typed})`;
}

function Visit({ visit }) {
  const yes = DANGER_SIGNS.filter(([key]) => visit[key] === true).map(([, label]) => label);
  const notAsked = DANGER_SIGNS.filter(([key]) => visit[key] === null).length;
  return (
    <article className="visit">
      <div className="visit-head">
        <strong>{new Date(visit.visitedAt).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' })}</strong>
        <span className="muted">
          {visit.recordedBy.lhwCode || visit.recordedBy.fullName} · synced {formatWhen(visit.syncedAt)}
        </span>
      </div>
      <dl>
        <div>
          <dt>BP</dt>
          <dd className="nowrap">
            {orDash(visit.systolicBpMmhg)}/{orDash(visit.diastolicBpMmhg)} mmHg
          </dd>
        </div>
        <div>
          <dt>Pulse</dt>
          <dd>{orDash(visit.pulseBpm, ' /min')}</dd>
        </div>
        <div>
          <dt>Weight</dt>
          <dd>{orDash(visit.weightKg, ' kg')}</dd>
        </div>
        <div>
          <dt>Temperature</dt>
          <dd>{orDash(visit.temperatureC, ' °C')}</dd>
        </div>
        <div>
          <dt>Blood sugar</dt>
          <dd>{bloodSugar(visit)}</dd>
        </div>
        <div>
          <dt>Fetal movement</dt>
          <dd>{FETAL_MOVEMENT[visit.fetalMovement] ?? 'Not recorded'}</dd>
        </div>
        <div>
          <dt>Anaemia signs</dt>
          <dd>{ANAEMIA[visit.anaemiaSigns] ?? visit.anaemiaSigns}</dd>
        </div>
        <div>
          <dt>Swelling · bleeding</dt>
          <dd>
            {yesNo(visit.swelling)} · {yesNo(visit.bleeding)}
          </dd>
        </div>
        <div>
          <dt>Fever · urine symptoms</dt>
          <dd>
            {yesNo(visit.fever)} · {yesNo(visit.urineSymptoms)}
          </dd>
        </div>
      </dl>
      {yes.length > 0 ? (
        <p className="danger-signs">Danger signs: {yes.join(', ')}</p>
      ) : (
        <p className="muted">No danger sign answered yes{notAsked ? ` (${notAsked} not asked)` : ''}.</p>
      )}
    </article>
  );
}

function VisitsDialog({ woman, onClose }) {
  const { request } = useAuth();
  const [visits, setVisits] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    request(`/women/${woman.id}/visits`)
      .then((result) => setVisits(result.visits))
      .catch((err) => setError(err.message));
  }, [request, woman.id]);

  return (
    <Dialog title={`Visits of ${woman.name} (${woman.patientCode})`} wide>
      <p className="muted">
        Latest first, as they reached the server. Visit times are the phone&apos;s clock. The danger-sign answers are
        decision support only (LI-5).
      </p>
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      {!visits && !error && <p className="muted">Loading…</p>}
      {visits && visits.length === 0 && <p className="muted">No visits have reached the server yet.</p>}
      {visits?.map((visit) => (
        <Visit key={visit.id} visit={visit} />
      ))}
      <div className="actions">
        <button type="button" onClick={onClose}>
          Close
        </button>
      </div>
    </Dialog>
  );
}

// Previous pregnancies / C-sections / stillbirths, as the column header says.
function historyText(history) {
  if (!history) return '–';
  return `${history.previousPregnancies} / ${history.previousCSections} / ${history.stillbirths}`;
}

export default function WomenPage() {
  const { request } = useAuth();
  const [search, setSearch] = useState('');
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [open, setOpen] = useState(null); // the woman whose visits are shown

  useEffect(() => {
    let cancelled = false;
    const params = new URLSearchParams();
    if (search.trim()) params.set('search', search.trim());
    const query = params.toString();
    request(`/women${query ? `?${query}` : ''}`)
      .then((result) => {
        if (cancelled) return;
        setData(result);
        setError(null);
      })
      .catch((err) => {
        if (!cancelled) setError(err.message);
      });
    return () => {
      cancelled = true;
    };
  }, [request, search]);

  const women = data?.women;

  return (
    <>
      <div className="page-header">
        <div>
          <h1>Registered women</h1>
          <p className="page-subtitle">
            Pregnant women registered by the LHWs in your areas, as their phones have synced them. The patient ID is the
            LHW code followed by the LHW&apos;s own counter.
          </p>
        </div>
        <div className="header-controls">
          <input
            className="search"
            type="search"
            aria-label="Search"
            placeholder="Name, patient ID, husband or village"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </div>
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      {women && women.length === 0 && (
        <p className="muted">{search.trim() ? 'No registered woman matches.' : 'No women have been registered yet.'}</p>
      )}
      {women && women.length > 0 && (
        <>
          <p className="muted">
            Showing {women.length} of {data.total}
          </p>
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Patient ID</th>
                  <th className="col-name">Name</th>
                  <th>Age</th>
                  <th className="col-place">Village</th>
                  <th>Month at registration</th>
                  <th>Registered on</th>
                  <th title="Previous pregnancies / previous C-sections / stillbirths">
                    History
                    <div className="muted">pregn. / C-sec. / stillb.</div>
                  </th>
                  <th>Known conditions</th>
                  <th>
                    Visits
                    <div className="muted">last visit</div>
                  </th>
                  <th>Registered by</th>
                  <th>Home GPS</th>
                </tr>
              </thead>
              <tbody>
                {women.map((w) => (
                  <tr key={w.id}>
                    <td className="nowrap">{w.patientCode}</td>
                    <td>
                      {w.name}
                      {w.husbandName && <div className="muted">Husband: {w.husbandName}</div>}
                      {w.contactNumber && <div className="muted">Contact: {w.contactNumber}</div>}
                    </td>
                    <td>{w.age ?? '–'}</td>
                    <td>
                      {w.household.village || '–'}
                      <div className="muted">{w.areaName}</div>
                    </td>
                    <td>{w.pregnancy ? w.pregnancy.monthAtRegistration : '–'}</td>
                    <td className="nowrap">{w.pregnancy ? w.pregnancy.registeredOn : '–'}</td>
                    <td>{historyText(w.obstetricHistory)}</td>
                    <td>{w.obstetricHistory?.knownConditions || '–'}</td>
                    <td className="nowrap">
                      {w.visits.count > 0 ? (
                        <button type="button" className="secondary" onClick={() => setOpen(w)} aria-label={`Visits of ${w.name}`}>
                          {w.visits.count}
                        </button>
                      ) : (
                        0
                      )}
                      {w.visits.lastVisitAt && <div className="muted">{formatWhen(w.visits.lastVisitAt, undefined, { withTime: false })}</div>}
                    </td>
                    <td className="nowrap">{w.registeredBy.lhwCode || w.registeredBy.fullName}</td>
                    <td>{w.household.latitude !== null ? 'Recorded' : 'Not recorded'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
      {open && <VisitsDialog woman={open} onClose={() => setOpen(null)} />}
    </>
  );
}
