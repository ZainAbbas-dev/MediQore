// M3 FE-2, M10 base: the sync conflict review queue. When a phone sends a visit
// for a pregnancy that already has a visit on the same day, the server holds it
// here instead of storing it (LI-7). A supervisor of the area, or an admin,
// compares the two visits and decides; every decision is in the audit log.
import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../auth/context';

const formatTime = (value) => (value ? new Date(value).toLocaleString() : '–');
const yesNo = (value) => (value ? 'Yes' : 'No');
const withUnit = (unit) => (value) => (value === null || value === undefined ? '–' : `${value} ${unit}`);

// The visit's fields as the phone sends them (docs/openapi.yaml, VisitData).
const VISIT_FIELDS = [
  ['visitedAt', 'Visit time (phone clock)', formatTime],
  ['systolicBpMmhg', 'Systolic BP', withUnit('mmHg')],
  ['diastolicBpMmhg', 'Diastolic BP', withUnit('mmHg')],
  ['weightKg', 'Weight', withUnit('kg')],
  ['temperatureC', 'Temperature', withUnit('°C')],
  ['pulseBpm', 'Pulse', withUnit('/min')],
  ['bloodSugarMmolL', 'Blood sugar', withUnit('mmol/L')],
  ['fetalMovement', 'Fetal movement', (value) => value ?? 'Not assessed'],
  ['swelling', 'Swelling', yesNo],
  ['bleeding', 'Bleeding', yesNo],
  ['fever', 'Fever', yesNo],
  ['anaemiaSigns', 'Anaemia signs', (value) => value ?? 'none'],
  ['urineSymptoms', 'Urine symptoms', yesNo],
];

// What each decision does, in the words shown on its button and after it.
const RESOLUTIONS = {
  keep_both: { button: 'Keep both visits', done: 'Both visits kept' },
  keep_existing: { button: 'Keep the stored visit', done: 'Stored visit kept; the held one was a duplicate' },
  keep_incoming: { button: 'Keep the held visit', done: 'Held visit kept; it replaced the stored one' },
};

const STATUSES = [
  ['pending', 'Waiting for a decision'],
  ['resolved', 'Decided'],
  ['all', 'All'],
];

function VisitComparison({ conflict }) {
  const existing = conflict.existing?.data ?? {};
  const incoming = conflict.incoming.data;
  return (
    <div className="table-scroll">
      <table className="comparison">
        <thead>
          <tr>
            <th>Field</th>
            <th>
              Stored visit
              {conflict.existing?.deleted && <span className="badge off">deleted</span>}
            </th>
            <th>Held visit</th>
          </tr>
        </thead>
        <tbody>
          {VISIT_FIELDS.map(([field, label, format]) => {
            const differs = format(existing[field]) !== format(incoming[field]);
            return (
              <tr key={field} className={differs ? 'differs' : undefined}>
                <th scope="row">{label}</th>
                <td>{conflict.existing ? format(existing[field]) : '–'}</td>
                <td>{format(incoming[field])}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

export default function ConflictsPage() {
  const { request } = useAuth();
  const [status, setStatus] = useState('pending');
  const [conflicts, setConflicts] = useState(null);
  const [error, setError] = useState(null);
  const [busyId, setBusyId] = useState(null);
  const [decided, setDecided] = useState(null);

  const load = useCallback(
    () =>
      request(`/conflicts?status=${status}`)
        .then((data) => {
          setConflicts(data.conflicts);
          setError(null);
        })
        .catch((err) => setError(err.message)),
    [request, status],
  );

  useEffect(() => {
    load();
  }, [load]);

  async function resolve(conflict, resolution) {
    setBusyId(conflict.id);
    setError(null);
    try {
      const result = await request(`/conflicts/${conflict.id}/resolve`, { method: 'POST', body: { resolution } });
      setDecided(result.conflict);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <>
      <h1>Sync conflicts</h1>
      <p className="muted">
        When a phone sends a visit for a pregnancy that already has a visit on the same day, the visit is held here
        instead of being stored, so nothing is overwritten. Compare the two visits and decide. The LHW&apos;s phone gets
        the decision at its next sync. Fields that differ are highlighted.
      </p>
      <div className="toolbar">
        <label htmlFor="conflict-status">Show</label>
        <select id="conflict-status" value={status} onChange={(e) => setStatus(e.target.value)}>
          {STATUSES.map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
      </div>
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      {decided && (
        <section className="notice" aria-label="Decision saved">
          <p>
            {RESOLUTIONS[decided.resolution].done}
            {decided.woman && ` for ${decided.woman.name} (${decided.woman.patientCode})`}.
          </p>
          <button type="button" className="secondary" onClick={() => setDecided(null)}>
            Done
          </button>
        </section>
      )}
      {conflicts && conflicts.length === 0 && (
        <p className="muted">{status === 'pending' ? 'No visits are waiting for a decision.' : 'No conflicts to show.'}</p>
      )}
      {conflicts?.map((conflict) => (
        <section key={conflict.id} className="conflict" aria-label={`Conflict ${conflict.woman?.patientCode ?? conflict.id}`}>
          <h2>
            {conflict.woman ? `${conflict.woman.name} (${conflict.woman.patientCode})` : 'Visit'}
            {conflict.status === 'resolved' && <span className="badge ok">decided</span>}
          </h2>
          <p className="muted">
            Same-day visit sent by {conflict.submittedBy.lhwCode || conflict.submittedBy.fullName || 'an LHW'} in{' '}
            {conflict.areaName}, held {formatTime(conflict.createdAt)}.
          </p>
          <VisitComparison conflict={conflict} />
          {conflict.status === 'pending' ? (
            <div className="row-actions">
              {Object.entries(RESOLUTIONS).map(([resolution, { button }]) => (
                <button
                  key={resolution}
                  type="button"
                  className={resolution === 'keep_both' ? undefined : 'secondary'}
                  disabled={busyId === conflict.id}
                  onClick={() => resolve(conflict, resolution)}
                >
                  {button}
                </button>
              ))}
            </div>
          ) : (
            <p>
              {RESOLUTIONS[conflict.resolution]?.done ?? conflict.resolution}, by {conflict.resolvedBy ?? '–'} on{' '}
              {formatTime(conflict.resolvedAt)}.
            </p>
          )}
        </section>
      ))}
    </>
  );
}
