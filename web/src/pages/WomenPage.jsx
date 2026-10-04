// M2 FE-1, FE-2, FE-3: registered women for supervisors and admins (M10 FE-1
// shows registered patients). A supervisor sees only their areas; the API
// scopes the list. Each row has the woman's pregnancy file in short.
import { useEffect, useState } from 'react';
import { useAuth } from '../auth/context';

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
      <h1>Registered women</h1>
      <p className="muted">
        Pregnant women registered by the LHWs in your areas, as their phones have synced them. The patient ID is the LHW
        code followed by the LHW&apos;s own counter.
      </p>
      <div className="toolbar">
        <label htmlFor="women-search">Search</label>
        <input
          id="women-search"
          type="search"
          placeholder="Name, patient ID, husband or village"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
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
                    Obstetric history
                    <div className="muted">previous / C-sections / stillbirths</div>
                  </th>
                  <th>Known conditions</th>
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
                    <td className="nowrap">{w.registeredBy.lhwCode || w.registeredBy.fullName}</td>
                    <td>{w.household.latitude !== null ? 'Recorded' : 'Not recorded'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </>
  );
}
