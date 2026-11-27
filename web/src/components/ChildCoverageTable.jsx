export default function ChildCoverageTable({ antigens, threshold }) {
  return (
    <div className="table-scroll">
      <table>
        <thead>
          <tr>
            <th scope="col">Antigen</th>
            <th scope="col">Eligible children</th>
            <th scope="col">Fully vaccinated</th>
            <th scope="col">Coverage</th>
          </tr>
        </thead>
        <tbody>
          {antigens.map((entry) => (
            <tr key={entry.antigen}>
              <th scope="row">{entry.antigen}</th>
              <td>{entry.eligible}</td>
              <td>{entry.fullyVaccinated}</td>
              <td>
                {entry.percentage === null ? '—' : `${entry.percentage}%`}
                {entry.lowCoverage && <div className="muted">Below {threshold}%</div>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
