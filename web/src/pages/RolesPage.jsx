// M10 FE-3: role permissions, for admins. The three roles are fixed; the table
// shows what each may do, from the same list the API checks on every request
// (GET /admin/roles). A role is given to an account on the accounts pages.
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../auth/context';

export default function RolesPage() {
  const { request } = useAuth();
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    request('/admin/roles')
      .then(setData)
      .catch((err) => setError(err.message));
  }, [request]);

  return (
    <>
      <h1>Roles and permissions</h1>
      <p className="muted">
        Every account has one of three roles. This is what each role may do; the server checks it on every request. Give
        a role to an account under <Link to="/admin/lhws">LHW accounts</Link> or{' '}
        <Link to="/admin/staff">Supervisors and admins</Link>.
      </p>
      {error && (
        <p className="error" role="alert">
          {error}
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
                      const allowed = permission.roles.includes(role.id);
                      return (
                        <td key={role.id} aria-label={`${role.label}: ${allowed ? 'allowed' : 'not allowed'}`}>
                          {allowed ? '✓' : '–'}
                        </td>
                      );
                    })}
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
