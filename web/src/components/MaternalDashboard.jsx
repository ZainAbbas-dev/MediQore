import { formatWhen } from '../format';

const LEVELS = [
  ['green', 'Green'],
  ['yellow', 'Yellow'],
  ['red', 'Red'],
];

export default function MaternalDashboard({ maternal, now, onPage }) {
  if (!maternal) return null;
  const { riskDistribution: risks, referrals, highRisk, limit, offset } = maternal;
  const assessed = risks.green + risks.yellow + risks.red;
  return (
    <>
      <div className="maternal-panels">
        <section className="panel" aria-labelledby="risk-title">
          <h2 className="panel-title" id="risk-title">Maternal risk distribution</h2>
          <p className="muted">{assessed ? `${assessed} assessed pregnancies` : 'No assessments match this period.'}</p>
          <div className="risk-distribution">
            {LEVELS.map(([level, label]) => (
              <div className="risk-distribution-row" key={level}>
                <span className={`risk-label risk-${level}`}>{label}</span>
                <meter aria-label={`${label} assessments`} min={0} max={assessed || 1} value={risks[level]} />
                <strong>{risks[level]}</strong>
              </div>
            ))}
          </div>
        </section>
        <section className="panel" aria-labelledby="referral-title">
          <h2 className="panel-title" id="referral-title">Referral follow-up</h2>
          <div className="value-list">
            <div><span>Completed</span><strong>{referrals.completed} of {referrals.total}</strong></div>
            <div><span>Completion rate</span><strong>{referrals.total ? `${Math.round(referrals.completed / referrals.total * 100)}%` : '–'}</strong></div>
            <div><span>Overdue follow-ups</span><strong>{referrals.overdue}</strong></div>
          </div>
        </section>
      </div>

      <section className="panel" aria-labelledby="high-risk-title">
        <h2 className="panel-title" id="high-risk-title">High-risk pregnancies</h2>
        {highRisk.length === 0 ? <p className="muted">No Red assessments match these filters.</p> : (
          <div className="table-scroll">
            <table>
              <thead><tr><th>Patient</th><th>Area</th><th>Assessment</th><th>Visit</th></tr></thead>
              <tbody>
                {highRisk.map((row) => (
                  <tr key={row.id}>
                    <td>{row.name}<div className="muted">{row.patientCode}</div></td>
                    <td>{row.area}</td>
                    <td><span className="risk-label risk-red">{row.emergency ? 'Red · Emergency' : 'Red'}</span></td>
                    <td>{formatWhen(row.visitedAt, now) ?? '–'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {risks.red > limit && (
          <div className="header-controls pager">
            <button type="button" className="secondary" disabled={offset === 0} onClick={() => onPage(Math.max(0, offset - limit))}>Previous cases</button>
            <span className="muted" aria-live="polite">{offset + 1}–{offset + highRisk.length} of {risks.red}</span>
            <button type="button" className="secondary" disabled={offset + limit >= risks.red} onClick={() => onPage(offset + limit)}>Next cases</button>
          </div>
        )}
      </section>
    </>
  );
}
