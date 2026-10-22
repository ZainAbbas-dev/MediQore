// M3 FE-2, M10 FE-3: the supervisor's Conflict Review page. Nothing a phone
// sends is overwritten without a decision here (LI-7):
// - outdated_edit: an edit made on an older version of the record than the
//   server's. It was not applied; keep the server's version or use the phone's.
// - possible_duplicate: a woman registered with the same name, husband's name
//   and household as one already on the server. Both are stored; decide whether
//   they are different women or the same woman (merged into the earlier record).
// - same_parent_same_day: a visit held by the earlier same-day rule.
// A supervisor of the area, or an admin, decides; every decision is in the
// audit log, and the phone gets it at its next sync.
import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../auth/context';

const formatTime = (value) => (value ? new Date(value).toLocaleString() : '–');
const yesNo = (value) => (value ? 'Yes' : 'No');
// A danger-sign checklist answer: null means the question was not asked (an older visit).
const answer = (value) => (value === null || value === undefined ? 'Not asked' : yesNo(value));
const orDash = (labels) => (value) => (value === null || value === undefined ? '–' : (labels[value] ?? value));
const withUnit = (unit) => (value) => (value === null || value === undefined ? '–' : `${value} ${unit}`);

const SUGAR_UNITS = { mmol_l: 'mmol/L', mg_dl: 'mg/dL' };
// Blood sugar is stored with the unit it was typed in; visits held before
// 22 Oct 2026 carry it in mmol/L only.
const bloodSugar = (value, data) => {
  if (value !== null && value !== undefined) return `${value} ${SUGAR_UNITS[data.bloodSugarUnit] ?? ''}`.trim();
  return data.bloodSugarMmolL === null || data.bloodSugarMmolL === undefined ? '–' : `${data.bloodSugarMmolL} mmol/L`;
};
const text = (value) => (value === null || value === undefined || value === '' ? '–' : String(value));

// Each synced record's fields as the phone sends them (docs/openapi.yaml).
const FIELDS = {
  visits: [
    ['visitedAt', 'Visit time (phone clock)', formatTime],
    ['systolicBpMmhg', 'Systolic BP', withUnit('mmHg')],
    ['diastolicBpMmhg', 'Diastolic BP', withUnit('mmHg')],
    ['weightKg', 'Weight', withUnit('kg')],
    ['temperatureC', 'Temperature', withUnit('°C')],
    ['pulseBpm', 'Pulse', withUnit('/min')],
    ['bloodSugarValue', 'Blood sugar', bloodSugar],
    ['bloodSugarMeasuredOn', 'Blood sugar measured on', orDash({})],
    ['bloodSugarSource', 'Blood sugar source', orDash({ glucometer: 'Glucometer', lab_report: 'Lab report' })],
    ['fetalMovement', 'Fetal movement', (value) => value ?? 'Not assessed'],
    ['swelling', 'Swelling', yesNo],
    ['bleeding', 'Bleeding', yesNo],
    ['fever', 'Fever', yesNo],
    ['anaemiaSigns', 'Anaemia signs', (value) => value ?? 'none'],
    ['urineSymptoms', 'Urine symptoms', yesNo],
    ['convulsions', 'Convulsions or fits', answer],
    ['severeHeadache', 'Severe headache', answer],
    ['blurredVision', 'Blurred vision', answer],
    ['severeAbdominalPain', 'Severe or upper abdominal pain', answer],
    ['fastBreathing', 'Fast or difficult breathing', answer],
    ['feverWithWeakness', 'Fever with weakness', answer],
  ],
  women: [
    ['patientCode', 'Patient ID', text],
    ['name', 'Name', text],
    ['age', 'Age', text],
    ['husbandName', "Husband's name", text],
    ['contactNumber', 'Contact number', text],
  ],
  households: [
    ['village', 'Village', text],
    ['address', 'Address', text],
    ['householdNumber', 'Household number', text],
    ['latitude', 'Latitude', text],
    ['longitude', 'Longitude', text],
  ],
  pregnancies: [
    ['registeredOn', 'Registered on', text],
    ['pregnancyMonthAtRegistration', 'Month at registration', text],
    ['lmpDate', 'Last menstrual period', text],
    ['reportedEdd', 'EDD on her card', text],
    ['estimatedDeliveryDate', 'Expected delivery date', text],
    ['eddBasis', 'Dated by', orDash({ lmp: 'LMP', edd: 'Card EDD', month: 'Month' })],
    ['status', 'Status', text],
    ['closedOn', 'Closed on', text],
  ],
  obstetric_history: [
    ['previousPregnancies', 'Earlier pregnancies', text],
    ['previousCSections', 'C-sections', text],
    ['stillbirths', 'Stillbirths', text],
    ['knownConditions', 'Known illness', (value) => (Array.isArray(value) ? value.join(', ') || 'none' : text(value))],
  ],
};

const RECORD_NAMES = {
  visits: 'visit',
  women: 'woman',
  households: 'household',
  pregnancies: 'pregnancy',
  obstetric_history: 'pregnancy history',
};

// What each decision does, in the words shown on its button and after it.
const RESOLUTIONS = {
  keep_server: { button: "Keep the server's version", done: "Server's version kept; the phone's edit was dropped" },
  use_device: { button: "Use the phone's edit", done: "Phone's edit applied as the new version" },
  different_people: { button: 'Different women: keep both', done: 'Kept as two different women' },
  same_person: { button: 'Same woman: merge', done: 'Merged into the earlier record' },
  keep_both: { button: 'Keep both visits', done: 'Both visits kept' },
  keep_existing: { button: 'Keep the stored visit', done: 'Stored visit kept; the held one was a duplicate' },
  keep_incoming: { button: 'Keep the held visit', done: 'Held visit kept; it replaced the stored one' },
};

// The decisions each reason allows, as the API lists them in `resolutions`.
const RESOLUTIONS_BY_REASON = {
  outdated_edit: ['keep_server', 'use_device'],
  possible_duplicate: ['different_people', 'same_person'],
  same_parent_same_day: ['keep_both', 'keep_existing', 'keep_incoming'],
};

const STATUSES = [
  ['pending', 'Waiting for a decision'],
  ['resolved', 'Decided'],
  ['all', 'All'],
];

// The two columns and the sentence under each conflict's heading.
function describe(conflict) {
  const who = conflict.submittedBy.lhwCode || conflict.submittedBy.fullName || 'an LHW';
  const record = RECORD_NAMES[conflict.table] ?? conflict.table;
  if (conflict.reason === 'outdated_edit') {
    return {
      kind: 'Edit made on an older version',
      text: `Edit of a ${record} sent by ${who} from version ${conflict.baseVersion ?? '–'}; the server has version ${
        conflict.existingVersion ?? '–'
      }. The edit was not applied.`,
      columns: [`Server (version ${conflict.existing?.version ?? conflict.existingVersion ?? '–'})`, "Phone's edit"],
    };
  }
  if (conflict.reason === 'possible_duplicate') {
    return {
      kind: 'Possible duplicate',
      text: `Woman registered by ${who} with the same name, husband's name and household as an earlier one. Both are stored.`,
      columns: ['Earlier registration', 'New registration'],
    };
  }
  return {
    kind: 'Same-day visit',
    text: `Same-day visit sent by ${who}.`,
    columns: ['Stored visit', 'Held visit'],
  };
}

function Comparison({ conflict, columns }) {
  const existing = conflict.existing?.data ?? {};
  const incoming = conflict.incoming.data ?? {};
  const fields = FIELDS[conflict.table] ?? Object.keys(incoming).map((key) => [key, key, text]);
  return (
    <div className="table-scroll">
      <table className="comparison">
        <thead>
          <tr>
            <th>Field</th>
            <th>
              {columns[0]}
              {conflict.existing?.deleted && <span className="badge off">deleted</span>}
            </th>
            <th>
              {columns[1]}
              {conflict.incoming.deleted && <span className="badge off">deleted</span>}
            </th>
          </tr>
        </thead>
        <tbody>
          {fields.map(([field, label, format]) => {
            const stored = conflict.existing ? format(existing[field], existing) : '–';
            const sent = format(incoming[field], incoming);
            return (
              <tr key={field} className={stored !== sent ? 'differs' : undefined}>
                <th scope="row">{label}</th>
                <td>{stored}</td>
                <td>{sent}</td>
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
    // Merging moves her visits and deletes the newer record, so it is confirmed first.
    if (resolution === 'same_person' && !window.confirm('Merge the new registration into the earlier one? Her visits move to the earlier record and the new record is deleted.')) {
      return;
    }
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
        Nothing a phone sends is overwritten without a decision here. An edit made on an older version of a record
        waits until you keep the server&apos;s version or use the phone&apos;s; a woman registered twice with the same
        name, husband&apos;s name and household is shown with the earlier registration. Compare and decide; fields that
        differ are highlighted. The LHW&apos;s phone gets the decision at its next sync.
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
            {RESOLUTIONS[decided.resolution]?.done ?? decided.resolution}
            {decided.woman && ` for ${decided.woman.name} (${decided.woman.patientCode})`}.
          </p>
          <button type="button" className="secondary" onClick={() => setDecided(null)}>
            Done
          </button>
        </section>
      )}
      {conflicts && conflicts.length === 0 && (
        <p className="muted">{status === 'pending' ? 'Nothing is waiting for a decision.' : 'No conflicts to show.'}</p>
      )}
      {conflicts?.map((conflict) => {
        const about = describe(conflict);
        const resolutions = conflict.resolutions ?? RESOLUTIONS_BY_REASON[conflict.reason] ?? [];
        return (
          <section key={conflict.id} className="conflict" aria-label={`Conflict ${conflict.woman?.patientCode ?? conflict.id}`}>
            <h2>
              {conflict.woman ? `${conflict.woman.name} (${conflict.woman.patientCode})` : about.kind}
              {conflict.status === 'resolved' && <span className="badge ok">decided</span>}
            </h2>
            <p className="muted">
              <span className="badge wait">{about.kind}</span> {about.text} {conflict.areaName}, {formatTime(conflict.createdAt)}.
            </p>
            <Comparison conflict={conflict} columns={about.columns} />
            {conflict.status === 'pending' ? (
              <div className="row-actions">
                {resolutions.map((resolution, index) => (
                  <button
                    key={resolution}
                    type="button"
                    className={index === 0 ? undefined : 'secondary'}
                    disabled={busyId === conflict.id}
                    onClick={() => resolve(conflict, resolution)}
                  >
                    {RESOLUTIONS[resolution]?.button ?? resolution}
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
        );
      })}
    </>
  );
}
