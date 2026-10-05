// M1 FE-1, FE-3: LHW accounts, for admins. Create an LHW (the system issues the
// LHW ID and a password), edit and reassign the area, deactivate or reactivate,
// and reset the password after the "sync before reset" warning (LI-8).
import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../auth/context';
import Dialog from '../components/Dialog';

const areaLabel = (a) => `${a.district} › ${a.tehsil} › ${a.unionCouncil} › ${a.name}`;
const formatTime = (value) => (value ? new Date(value).toLocaleString() : 'Never');

function LhwForm({ areas, lhw, onSubmit, onCancel }) {
  const [fullName, setFullName] = useState(lhw?.fullName ?? '');
  const [phone, setPhone] = useState(lhw?.phone ?? '');
  const [areaId, setAreaId] = useState(lhw?.area.id ?? '');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const areaChanged = lhw && areaId !== lhw.area.id;

  async function handleSubmit(event) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await onSubmit({ fullName: fullName.trim(), phone: phone.trim(), areaId });
    } catch (err) {
      setError(err.code === 'VALIDATION_ERROR' ? 'Check the name and phone number.' : err.message);
      setBusy(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="stack">
      <label htmlFor="lhw-name">Full name</label>
      <input id="lhw-name" value={fullName} onChange={(e) => setFullName(e.target.value)} required minLength={2} />
      <label htmlFor="lhw-phone">Phone number (optional)</label>
      <input id="lhw-phone" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="03xx xxxxxxx" />
      <label htmlFor="lhw-area">Area</label>
      <select id="lhw-area" value={areaId} onChange={(e) => setAreaId(e.target.value)} required>
        <option value="">Choose an area</option>
        {areas.map((a) => (
          <option key={a.id} value={a.id}>
            {areaLabel(a)}
          </option>
        ))}
      </select>
      {areaChanged && (
        <p className="warning">
          After the change, the phone downloads the new area&apos;s records at its next sign-in. Records the phone made in
          the old area and has not synced yet still go to the old area when they arrive.
        </p>
      )}
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      <div className="actions">
        <button type="submit" disabled={busy}>
          {lhw ? 'Save changes' : 'Create LHW'}
        </button>
        <button type="button" className="secondary" onClick={onCancel}>
          Cancel
        </button>
      </div>
    </form>
  );
}

function Credentials({ credentials, intro, onDone }) {
  return (
    <>
      <p>{intro}</p>
      <dl className="credentials">
        <dt>LHW ID (username)</dt>
        <dd className="code">{credentials.username}</dd>
        <dt>Password</dt>
        <dd className="code">{credentials.password}</dd>
      </dl>
      <p className="muted">
        The password is shown only now. On first sign-in the LHW&apos;s phone also needs approval: issue its code under
        Phone approvals.
      </p>
      <div className="actions">
        <button type="button" onClick={onDone}>
          Done
        </button>
      </div>
    </>
  );
}

export default function LhwsPage() {
  const { request } = useAuth();
  const [lhws, setLhws] = useState(null);
  const [areas, setAreas] = useState([]);
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('all');
  const [error, setError] = useState(null);
  const [dialog, setDialog] = useState(null); // { type, lhw?, credentials? }

  const load = useCallback(() => {
    const params = new URLSearchParams();
    if (search.trim()) params.set('search', search.trim());
    if (status !== 'all') params.set('status', status);
    const query = params.toString();
    return request(`/admin/lhws${query ? `?${query}` : ''}`)
      .then((data) => setLhws(data.lhws))
      .catch((err) => setError(err.message));
  }, [request, search, status]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    request('/admin/areas')
      .then((data) => setAreas(data.areas))
      .catch((err) => setError(err.message));
  }, [request]);

  const close = () => setDialog(null);

  async function create(values) {
    const result = await request('/admin/lhws', { method: 'POST', body: withoutEmptyPhone(values) });
    setDialog({ type: 'created', lhw: result.lhw, credentials: result.credentials });
    load();
  }

  async function save(lhw, values) {
    await request(`/admin/lhws/${lhw.id}`, { method: 'PATCH', body: values });
    close();
    load();
  }

  async function run(action) {
    setError(null);
    try {
      await action();
    } catch (err) {
      setError(err.message);
      close();
    }
  }

  const setActive = (lhw, active) =>
    run(async () => {
      await request(`/admin/lhws/${lhw.id}/${active ? 'activate' : 'deactivate'}`, { method: 'POST' });
      close();
      load();
    });

  const resetPassword = (lhw) =>
    run(async () => {
      const result = await request(`/admin/lhws/${lhw.id}/reset-password`, { method: 'POST' });
      setDialog({ type: 'reset-done', lhw, credentials: result.credentials });
    });

  return (
    <>
      <div className="page-header">
        <h1>LHW accounts</h1>
        <button type="button" onClick={() => setDialog({ type: 'create' })}>
          Add LHW
        </button>
      </div>
      <div className="toolbar">
        <label htmlFor="lhw-search">Search</label>
        <input
          id="lhw-search"
          type="search"
          placeholder="Name or LHW ID"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <label htmlFor="lhw-status">Status</label>
        <select id="lhw-status" value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="all">All</option>
          <option value="active">Active</option>
          <option value="inactive">Deactivated</option>
        </select>
      </div>
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      {lhws && lhws.length === 0 && <p className="muted">No LHWs match.</p>}
      {lhws && lhws.length > 0 && (
        <table>
          <thead>
            <tr>
              <th>LHW ID</th>
              <th>Name</th>
              <th>Area</th>
              <th>Phone</th>
              <th>Status</th>
              <th>Phones</th>
              <th>Last sign-in</th>
              <th aria-label="Actions" />
            </tr>
          </thead>
          <tbody>
            {lhws.map((lhw) => (
              <tr key={lhw.id}>
                <td>{lhw.lhwCode}</td>
                <td>{lhw.fullName}</td>
                <td title={`${lhw.area.district.name} › ${lhw.area.tehsil.name} › ${lhw.area.unionCouncil.name}`}>
                  {lhw.area.name}
                </td>
                <td>{lhw.phone || '–'}</td>
                <td>
                  <span className={lhw.isActive ? 'badge ok' : 'badge off'}>{lhw.isActive ? 'Active' : 'Deactivated'}</span>
                </td>
                <td>
                  {lhw.devices.approved} approved
                  {lhw.devices.pending > 0 && `, ${lhw.devices.pending} waiting`}
                </td>
                <td>{formatTime(lhw.lastLoginAt)}</td>
                <td className="row-actions">
                  <button type="button" className="secondary" onClick={() => setDialog({ type: 'edit', lhw })} aria-label={`Edit ${lhw.lhwCode}`}>
                    Edit
                  </button>
                  {lhw.isActive ? (
                    <button type="button" className="secondary" onClick={() => setDialog({ type: 'deactivate', lhw })} aria-label={`Deactivate ${lhw.lhwCode}`}>
                      Deactivate
                    </button>
                  ) : (
                    <button type="button" className="secondary" onClick={() => setActive(lhw, true)} aria-label={`Activate ${lhw.lhwCode}`}>
                      Activate
                    </button>
                  )}
                  <button type="button" className="secondary" onClick={() => setDialog({ type: 'reset', lhw })} aria-label={`Reset password of ${lhw.lhwCode}`}>
                    Reset password
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {dialog?.type === 'create' && (
        <Dialog title="Add LHW">
          <p className="muted">The system issues the LHW ID and a password.</p>
          <LhwForm areas={areas} onSubmit={create} onCancel={close} />
        </Dialog>
      )}
      {dialog?.type === 'created' && (
        <Dialog title="LHW created">
          <Credentials credentials={dialog.credentials} intro={`Give these to ${dialog.lhw.fullName}.`} onDone={close} />
        </Dialog>
      )}
      {dialog?.type === 'edit' && (
        <Dialog title={`Edit ${dialog.lhw.lhwCode}`}>
          <LhwForm areas={areas} lhw={dialog.lhw} onSubmit={(values) => save(dialog.lhw, values)} onCancel={close} />
        </Dialog>
      )}
      {dialog?.type === 'deactivate' && (
        <Dialog title={`Deactivate ${dialog.lhw.lhwCode}?`}>
          <p>
            {dialog.lhw.fullName} will not be able to sign in or sync. Records already on the server stay. You can
            reactivate the account later.
          </p>
          <div className="actions">
            <button type="button" className="danger" onClick={() => setActive(dialog.lhw, false)}>
              Deactivate
            </button>
            <button type="button" className="secondary" onClick={close}>
              Cancel
            </button>
          </div>
        </Dialog>
      )}
      {dialog?.type === 'reset' && (
        <Dialog title={`Reset the password of ${dialog.lhw.lhwCode}?`}>
          <p className="warning">
            Sync before reset: make sure {dialog.lhw.fullName} has synced the phone. Records on the phone that are not
            synced cannot be read after the reset (LI-8).
          </p>
          <div className="actions">
            <button type="button" className="danger" onClick={() => resetPassword(dialog.lhw)}>
              Reset password
            </button>
            <button type="button" className="secondary" onClick={close}>
              Cancel
            </button>
          </div>
        </Dialog>
      )}
      {dialog?.type === 'reset-done' && (
        <Dialog title="New password">
          <Credentials credentials={dialog.credentials} intro={`Give the new password to ${dialog.lhw.fullName}.`} onDone={close} />
        </Dialog>
      )}
    </>
  );
}

function withoutEmptyPhone(values) {
  return values.phone ? values : { fullName: values.fullName, areaId: values.areaId };
}
