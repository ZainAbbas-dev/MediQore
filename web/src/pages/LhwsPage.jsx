// M1 FE-1, FE-3: LHW accounts, for admins. Create an LHW (the system issues the
// LHW ID and a password), generate the one-time activation code for her phone
// (M1 FE-2), edit and reassign the area, deactivate or reactivate, and reset the
// password. A password reset loses no data on the phone (LI-8).
// Activation codes and passwords are shown once, in their dialog only.
import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../auth/context';
import Dialog from '../components/Dialog';

const areaLabel = (a) => `${a.district} › ${a.tehsil} › ${a.unionCouncil} › ${a.name}`;
const formatTime = (value) => (value ? new Date(value).toLocaleString() : 'Never');
const formatDate = (value) => new Date(value).toLocaleDateString();

// The phone column and status of the final design (screen 21).
function phoneState(lhw) {
  if (lhw.devices.activated > 0) return `Activated ${formatDate(lhw.devices.lastActivatedAt)}`;
  if (lhw.activationCodeExpiresAt) return 'Code issued, not used';
  return 'Not activated';
}

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
        The password is shown only now. To sign in on her phone the first time, she also needs an activation code: use{' '}
        <strong>New activation code</strong> in the list.
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

  const issueActivationCode = (lhw) =>
    run(async () => {
      const result = await request(`/admin/lhws/${lhw.id}/activation-code`, { method: 'POST' });
      setDialog({ type: 'activation-code', lhw: result.lhw, code: result.activationCode, expiresAt: result.expiresAt });
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
              <th>LHW phone</th>
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
                  {!lhw.isActive ? (
                    <span className="badge off">Deactivated</span>
                  ) : lhw.devices.activated > 0 ? (
                    <span className="badge ok">Active</span>
                  ) : (
                    <span className="badge wait">Waiting to activate</span>
                  )}
                </td>
                <td>{phoneState(lhw)}</td>
                <td>{formatTime(lhw.lastLoginAt)}</td>
                <td className="row-actions">
                  <button type="button" className="secondary" onClick={() => setDialog({ type: 'edit', lhw })} aria-label={`Edit ${lhw.lhwCode}`}>
                    Edit
                  </button>
                  {lhw.isActive && (
                    <button
                      type="button"
                      className={lhw.devices.activated > 0 ? 'secondary' : undefined}
                      onClick={() => setDialog({ type: 'new-code', lhw })}
                      aria-label={`New activation code for ${lhw.lhwCode}`}
                    >
                      New activation code
                    </button>
                  )}
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
      {dialog?.type === 'new-code' && (
        <Dialog title={`New activation code for ${dialog.lhw.lhwCode}?`}>
          <p>
            {dialog.lhw.fullName} types it once on her phone, with her LHW ID and password, to activate it. It works on
            one phone, for 48 hours. A code issued earlier and not used stops working.
          </p>
          {dialog.lhw.devices.activated > 0 && (
            <p className="warning">
              She already has an activated phone. Issue a new code only for a new or reinstalled phone; records on the
              old phone that were not synced cannot be recovered (LI-8).
            </p>
          )}
          <div className="actions">
            <button type="button" onClick={() => issueActivationCode(dialog.lhw)}>
              Generate code
            </button>
            <button type="button" className="secondary" onClick={close}>
              Cancel
            </button>
          </div>
        </Dialog>
      )}
      {dialog?.type === 'activation-code' && (
        <Dialog title={`Activation code for ${dialog.lhw.lhwCode} (${dialog.lhw.area.name})`}>
          <p className="code">{dialog.code}</p>
          <p className="muted">
            Give it to {dialog.lhw.fullName} with her LHW ID and password. It works once, on one phone, and expires on{' '}
            {formatTime(dialog.expiresAt)}. It is shown only now; MediQore keeps only its hash.
          </p>
          <div className="actions">
            <button type="button" onClick={close}>
              Done
            </button>
          </div>
        </Dialog>
      )}
      {dialog?.type === 'deactivate' && (
        <Dialog title={`Deactivate ${dialog.lhw.lhwCode}?`}>
          <p>
            {dialog.lhw.fullName} will not be able to sign in or sync, from the next time her phone connects. Her unused
            activation code stops working. Records already on the server stay. You can reactivate the account later.
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
          <p>
            {dialog.lhw.fullName} gets a new password and signs in with it once, when her phone next connects. The records
            and the PIN on her phone stay as they are (LI-8). If she forgot her PIN, use PIN reset codes instead.
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
