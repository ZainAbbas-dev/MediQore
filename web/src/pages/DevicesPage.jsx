// M1 FE-2: phone approvals (decision 0002). A user signing in on a new phone
// waits for a one-time code; an admin, or the supervisor of the LHW's area,
// issues it here and reads it out or hands it over.
import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../auth/context';

const formatTime = (value) => (value ? new Date(value).toLocaleString() : '–');

// The app's code screen shows the same last six characters, so the person
// issuing the code can check it is for the right phone.
const phoneIdSuffix = (id) => id.slice(-6);

export default function DevicesPage() {
  const { request } = useAuth();
  const [devices, setDevices] = useState(null);
  const [error, setError] = useState(null);
  const [issued, setIssued] = useState(null);
  const [busyId, setBusyId] = useState(null);

  const load = useCallback(
    () =>
      request('/devices/pending')
        .then((data) => {
          setDevices(data.devices);
          setError(null);
        })
        .catch((err) => setError(err.message)),
    [request],
  );

  useEffect(() => {
    load();
  }, [load]);

  async function issueCode(device) {
    setBusyId(device.id);
    setError(null);
    try {
      const result = await request(`/devices/${device.id}/code`, { method: 'POST' });
      setIssued(result);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <>
      <h1>Phone approvals</h1>
      <p className="muted">
        A phone must be approved once before it can be used. When someone signs in on a new phone, it appears here.
        Issue a code and give it to them in person or by phone call; they type it in the app.
      </p>
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      {issued && (
        <section className="notice" aria-label="One-time code">
          <p>
            One-time code for <strong>{issued.device.user.fullName}</strong> ({issued.device.user.username}):
          </p>
          <p className="code">{issued.code}</p>
          <p className="muted">
            It works once, only on the phone whose ID ends in {phoneIdSuffix(issued.device.id)}, until{' '}
            {formatTime(issued.expiresAt)}. Issuing a new code cancels this one.
            It is not shown again.
          </p>
          <button type="button" className="secondary" onClick={() => setIssued(null)}>
            Done
          </button>
        </section>
      )}
      {devices && devices.length === 0 && <p className="muted">No phones are waiting for approval.</p>}
      {devices && devices.length > 0 && (
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>User</th>
              <th>Area</th>
              <th>Phone</th>
              <th>Phone ID ends in</th>
              <th>First seen</th>
              <th>Code</th>
              <th aria-label="Actions" />
            </tr>
          </thead>
          <tbody>
            {devices.map((device) => (
              <tr key={device.id}>
                <td>{device.user.fullName}</td>
                <td>
                  {device.user.username}
                  {device.user.role !== 'lhw' && <span className="badge">{device.user.role}</span>}
                </td>
                <td>{device.user.areaName || '–'}</td>
                <td>{device.model || 'Unknown model'}</td>
                <td className="mono">{phoneIdSuffix(device.id)}</td>
                <td>{formatTime(device.firstSeenAt)}</td>
                <td>{device.codeExpiresAt ? `Valid until ${formatTime(device.codeExpiresAt)}` : 'None issued'}</td>
                <td>
                  <button type="button" onClick={() => issueCode(device)} disabled={busyId === device.id}>
                    {device.codeExpiresAt ? 'Issue new code' : 'Issue code'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </>
  );
}
