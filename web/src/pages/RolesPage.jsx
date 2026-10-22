// M10 FE-3: role permissions, for admins. The three roles are fixed; the table
// shows what each may do, from the same list the API checks on every request
// (GET /admin/roles). An admin can tick or clear the cells the API marks as
// editable and save them (PUT /admin/roles/permissions, audited). LHWs only
// sync, and admins always keep role management, so those cells are fixed.
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../auth/context';

const key = (role, permission) => `${role}:${permission}`;

export default function RolesPage() {
  const { request } = useAuth();
  const [data, setData] = useState(null);
  const [draft, setDraft] = useState({});
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    request('/admin/roles')
      .then(setData)
      .catch((err) => setError(err.message));
  }, [request]);

  const holds = (permission, role) => draft[key(role, permission.id)] ?? permission.roles.includes(role);

  // The cells changed from what the server holds.
  const changes = useMemo(
    () =>
      (data?.permissions ?? []).flatMap((permission) =>
        (permission.editableRoles ?? [])
          .filter((role) => key(role, permission.id) in draft && draft[key(role, permission.id)] !== permission.roles.includes(role))
          .map((role) => ({ role, permission: permission.id, granted: draft[key(role, permission.id)] })),
      ),
    [data, draft],
  );

  function toggle(permission, role) {
    setSaved(false);
    setDraft((current) => ({ ...current, [key(role, permission.id)]: !holds(permission, role) }));
  }

  async function save() {
    setSaving(true);
    setError(null);
    try {
      setData(await request('/admin/roles/permissions', { method: 'PUT', body: { changes } }));
      setDraft({});
      setSaved(true);
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <h1>Roles and permissions</h1>
      <p className="muted">
        Every account has one of three roles. This is what each role may do; the server checks it on every request. Tick
        or clear a box and save to change it; every change is in the audit log, and an account sees the change at its
        next sign-in. LHWs only sync from the app. Give a role to an account under{' '}
        <Link to="/admin/lhws">LHW accounts</Link> or <Link to="/admin/staff">Supervisors and admins</Link>.
      </p>
      <p className="muted">
        An administration permission given to supervisors works only on each supervisor&apos;s own areas: their LHWs,
        the hospitals of their districts and what they and their LHWs did in the audit log. Role management, supervisor
        and admin accounts and the geography stay with admins.
      </p>
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      {saved && (
        <p className="notice" role="status">
          Permissions saved.
        </p>
      )}
      {data && (
        <>
          <section className="cards">
            {data.roles.map((role) => (
              <div key={role.id} className="card role-card">
                <div className="card-value">{role.label}</div>
                <div className="card-label">{role.description}</div>
              </div>
            ))}
          </section>
          <div className="table-scroll">
            <table className="permissions">
              <thead>
                <tr>
                  <th>Permission</th>
                  {data.roles.map((role) => (
                    <th key={role.id}>{role.label}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {data.permissions.map((permission) => (
                  <tr key={permission.id}>
                    <th scope="row">{permission.label}</th>
                    {data.roles.map((role) => {
                      const allowed = holds(permission, role.id);
                      if (permission.editableRoles?.includes(role.id)) {
                        return (
                          <td key={role.id}>
                            <input
                              type="checkbox"
                              aria-label={`${role.label}: ${permission.label}`}
                              checked={allowed}
                              onChange={() => toggle(permission, role.id)}
                            />
                          </td>
                        );
                      }
                      return (
                        <td key={role.id} aria-label={`${role.label}: ${allowed ? 'allowed' : 'not allowed'} (fixed)`}>
                          {allowed ? '✓' : '–'}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="row-actions">
            <button type="button" disabled={changes.length === 0 || saving} onClick={save}>
              {saving ? 'Saving…' : 'Save changes'}
            </button>
            {changes.length > 0 && (
              <button type="button" className="secondary" disabled={saving} onClick={() => setDraft({})}>
                Undo
              </button>
            )}
          </div>
        </>
      )}
    </>
  );
}
