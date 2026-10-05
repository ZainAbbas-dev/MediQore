// M10 FE-3: supervisor and admin accounts, for admins. Create one (the admin
// picks the username, the system issues a password shown once), choose a
// supervisor's areas, change the role, deactivate or reactivate, and reset the
// password. LHW accounts are on their own page (M1 FE-1).
import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../auth/context';
import AreaChecklist from '../components/AreaChecklist';
import Dialog from '../components/Dialog';

const formatTime = (value) => (value ? new Date(value).toLocaleString() : 'Never');
const ROLE_LABELS = { supervisor: 'Supervisor', admin: 'Admin' };

function StaffForm({ areas, staff, ownAccount, onSubmit, onCancel }) {
  const [role, setRole] = useState(staff?.role ?? 'supervisor');
  const [username, setUsername] = useState('');
  const [fullName, setFullName] = useState(staff?.fullName ?? '');
  const [phone, setPhone] = useState(staff?.phone ?? '');
  const [areaIds, setAreaIds] = useState(staff?.areas.map((a) => a.id) ?? []);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(event) {
    event.preventDefault();
    if (role === 'supervisor' && areaIds.length === 0) {
      setError('Choose at least one area for a supervisor.');
      return;
    }
    setBusy(true);
    setError(null);
    const values = { role, fullName: fullName.trim(), phone: phone.trim(), areaIds: role === 'supervisor' ? areaIds : [] };
    if (!staff) values.username = username.trim().toLowerCase();
    try {
      await onSubmit(values);
    } catch (err) {
      setError(err.code === 'VALIDATION_ERROR' ? 'Check the username, name and phone number.' : err.message);
      setBusy(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="stack">
      <label htmlFor="staff-role">Role</label>
      <select id="staff-role" value={role} onChange={(e) => setRole(e.target.value)} disabled={ownAccount}>
        <option value="supervisor">Supervisor: sees the areas chosen below</option>
        <option value="admin">Admin: sees every area and manages the system</option>
      </select>
      {ownAccount && <p className="muted">You cannot change the role of your own account.</p>}
      {!staff && (
        <>
          <label htmlFor="staff-username">Username</label>
          <input
            id="staff-username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
            pattern="[A-Za-z][A-Za-z0-9._\-]{2,31}"
            title="3 to 32 letters, digits, dots, dashes or underscores, starting with a letter"
            placeholder="for example sup.rawalpindi"
          />
        </>
      )}
      <label htmlFor="staff-name">Full name</label>
      <input id="staff-name" value={fullName} onChange={(e) => setFullName(e.target.value)} required minLength={2} />
      <label htmlFor="staff-phone">Phone number (optional)</label>
      <input id="staff-phone" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="03xx xxxxxxx" />
      {role === 'supervisor' && <AreaChecklist areas={areas} selected={areaIds} onChange={setAreaIds} />}
      {staff && role !== staff.role && (
        <p className="warning">Changing the role signs {staff.fullName} out; the new role applies at their next sign-in.</p>
      )}
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      <div className="actions">
        <button type="submit" disabled={busy}>
          {staff ? 'Save changes' : 'Create account'}
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
        <dt>Username</dt>
        <dd className="code">{credentials.username}</dd>
        <dt>Password</dt>
        <dd className="code">{credentials.password}</dd>
      </dl>
      <p className="muted">The password is shown only now. They sign in on this portal.</p>
      <div className="actions">
        <button type="button" onClick={onDone}>
          Done
        </button>
      </div>
    </>
  );
}

export default function StaffPage() {
  const { request, user } = useAuth();
  const [staff, setStaff] = useState(null);
  const [areas, setAreas] = useState([]);
  const [search, setSearch] = useState('');
  const [role, setRole] = useState('');
  const [error, setError] = useState(null);
  const [dialog, setDialog] = useState(null); // { type, staff?, credentials? }

  const load = useCallback(() => {
    const params = new URLSearchParams();
    if (search.trim()) params.set('search', search.trim());
    if (role) params.set('role', role);
    const query = params.toString();
    return request(`/admin/staff${query ? `?${query}` : ''}`)
      .then((data) => setStaff(data.staff))
      .catch((err) => setError(err.message));
  }, [request, search, role]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    request('/admin/areas')
      .then((data) => setAreas(data.areas))
      .catch((err) => setError(err.message));
  }, [request]);

  const close = () => setDialog(null);
  const withoutEmpty = (values) => (values.phone ? values : { ...values, phone: undefined });

  async function create(values) {
    const result = await request('/admin/staff', { method: 'POST', body: withoutEmpty(values) });
    setDialog({ type: 'created', staff: result.staff, credentials: result.credentials });
    load();
  }

  async function save(account, values) {
    const changes = { ...values };
    if (account.id === user?.id) delete changes.role;
    await request(`/admin/staff/${account.id}`, { method: 'PATCH', body: changes });
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

  const setActive = (account, active) =>
    run(async () => {
      await request(`/admin/staff/${account.id}/${active ? 'activate' : 'deactivate'}`, { method: 'POST' });
      close();
      load();
    });

  const resetPassword = (account) =>
    run(async () => {
      const result = await request(`/admin/staff/${account.id}/reset-password`, { method: 'POST' });
      setDialog({ type: 'reset-done', staff: account, credentials: result.credentials });
    });

  return (
    <>
      <div className="page-header">
        <h1>Supervisors and admins</h1>
        <button type="button" onClick={() => setDialog({ type: 'create' })}>
          Add account
        </button>
      </div>
      <p className="muted">
        Accounts for the portal. A supervisor sees the records, LHWs and phones of their areas; an admin sees everything.
        LHW accounts are under LHW accounts.
      </p>
      <div className="toolbar">
        <label htmlFor="staff-search">Search</label>
        <input id="staff-search" type="search" placeholder="Name or username" value={search} onChange={(e) => setSearch(e.target.value)} />
        <label htmlFor="staff-role-filter">Role</label>
        <select id="staff-role-filter" value={role} onChange={(e) => setRole(e.target.value)}>
          <option value="">All</option>
          <option value="supervisor">Supervisors</option>
          <option value="admin">Admins</option>
        </select>
      </div>
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      {staff && staff.length === 0 && <p className="muted">No accounts match.</p>}
      {staff && staff.length > 0 && (
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Username</th>
                <th>Name</th>
                <th>Role</th>
                <th>Areas</th>
                <th>Phone</th>
                <th>Status</th>
                <th>Last sign-in</th>
                <th aria-label="Actions" />
              </tr>
            </thead>
            <tbody>
              {staff.map((account) => (
                <tr key={account.id}>
                  <td className="nowrap">
                    {account.username}
                    {account.id === user?.id && <span className="badge">you</span>}
                  </td>
                  <td>{account.fullName}</td>
                  <td>{ROLE_LABELS[account.role]}</td>
                  <td>
                    {account.role === 'admin'
                      ? 'All areas'
                      : account.areas.map((a) => (
                          <div key={a.id} title={`${a.district} › ${a.tehsil} › ${a.unionCouncil}`}>
                            {a.name}
                          </div>
                        ))}
                  </td>
                  <td>{account.phone || '–'}</td>
                  <td>
                    <span className={account.isActive ? 'badge ok' : 'badge off'}>{account.isActive ? 'Active' : 'Deactivated'}</span>
                  </td>
                  <td>{formatTime(account.lastLoginAt)}</td>
                  <td className="row-actions">
                    <button type="button" className="secondary" onClick={() => setDialog({ type: 'edit', staff: account })} aria-label={`Edit ${account.username}`}>
                      Edit
                    </button>
                    {account.id !== user?.id &&
                      (account.isActive ? (
                        <button type="button" className="secondary" onClick={() => setDialog({ type: 'deactivate', staff: account })} aria-label={`Deactivate ${account.username}`}>
                          Deactivate
                        </button>
                      ) : (
                        <button type="button" className="secondary" onClick={() => setActive(account, true)} aria-label={`Activate ${account.username}`}>
                          Activate
                        </button>
                      ))}
                    <button type="button" className="secondary" onClick={() => setDialog({ type: 'reset', staff: account })} aria-label={`Reset password of ${account.username}`}>
                      Reset password
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {dialog?.type === 'create' && (
        <Dialog title="Add supervisor or admin">
          <StaffForm areas={areas} onSubmit={create} onCancel={close} />
        </Dialog>
      )}
      {dialog?.type === 'created' && (
        <Dialog title="Account created">
          <Credentials credentials={dialog.credentials} intro={`Give these to ${dialog.staff.fullName}.`} onDone={close} />
        </Dialog>
      )}
      {dialog?.type === 'edit' && (
        <Dialog title={`Edit ${dialog.staff.username}`}>
          <StaffForm
            areas={areas}
            staff={dialog.staff}
            ownAccount={dialog.staff.id === user?.id}
            onSubmit={(values) => save(dialog.staff, values)}
            onCancel={close}
          />
        </Dialog>
      )}
      {dialog?.type === 'deactivate' && (
        <Dialog title={`Deactivate ${dialog.staff.username}?`}>
          <p>
            {dialog.staff.fullName} is signed out and cannot sign in again until the account is reactivated. Nothing they
            recorded is removed.
          </p>
          <div className="actions">
            <button type="button" className="danger" onClick={() => setActive(dialog.staff, false)}>
              Deactivate
            </button>
            <button type="button" className="secondary" onClick={close}>
              Cancel
            </button>
          </div>
        </Dialog>
      )}
      {dialog?.type === 'reset' && (
        <Dialog title={`Reset the password of ${dialog.staff.username}?`}>
          <p>The current password stops working and {dialog.staff.fullName} is signed out everywhere.</p>
          <div className="actions">
            <button type="button" className="danger" onClick={() => resetPassword(dialog.staff)}>
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
          <Credentials credentials={dialog.credentials} intro={`Give the new password to ${dialog.staff.fullName}.`} onDone={close} />
        </Dialog>
      )}
    </>
  );
}
