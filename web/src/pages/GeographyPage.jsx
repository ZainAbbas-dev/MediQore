// M10 FE-3: the district > tehsil > Union Council > area structure, for admins.
// Four columns: choosing a unit shows the units under it. Each level can add,
// rename and delete; the API refuses to delete a unit that is still in use and
// says what uses it. LHWs and supervisors are given areas from this structure.
import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../auth/context';
import Dialog from '../components/Dialog';

const LEVELS = [
  { level: 'districts', title: 'Districts', label: 'district', children: 'tehsils' },
  { level: 'tehsils', title: 'Tehsils', label: 'tehsil', children: 'unionCouncils' },
  { level: 'union-councils', title: 'Union Councils', label: 'Union Council', children: 'areas' },
  { level: 'areas', title: 'Areas', label: 'area', children: null },
];

const plural = (n, word) => `${n} ${word}${n === 1 ? '' : 's'}`;

function AddForm({ label, onAdd }) {
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);

  async function handleSubmit(event) {
    event.preventDefault();
    setBusy(true);
    const added = await onAdd(name.trim());
    setBusy(false);
    if (added) setName('');
  }

  return (
    <form className="add-unit" onSubmit={handleSubmit}>
      <input aria-label={`New ${label}`} placeholder={`New ${label}`} value={name} onChange={(e) => setName(e.target.value)} required minLength={2} maxLength={100} />
      <button type="submit" disabled={busy}>
        Add
      </button>
    </form>
  );
}

function RenameForm({ unit, onRename, onCancel }) {
  const [name, setName] = useState(unit.name);
  return (
    <form
      className="stack"
      onSubmit={(event) => {
        event.preventDefault();
        onRename(name.trim());
      }}
    >
      <label htmlFor="unit-name">Name</label>
      <input id="unit-name" value={name} onChange={(e) => setName(e.target.value)} required minLength={2} maxLength={100} />
      <div className="actions">
        <button type="submit">Save</button>
        <button type="button" className="secondary" onClick={onCancel}>
          Cancel
        </button>
      </div>
    </form>
  );
}

export default function GeographyPage() {
  const { request } = useAuth();
  const [tree, setTree] = useState(null);
  const [path, setPath] = useState([]); // chosen unit IDs, one per level
  const [error, setError] = useState(null);
  const [notice, setNotice] = useState(null);
  const [dialog, setDialog] = useState(null); // { type: 'rename' | 'delete', level, unit }

  const load = useCallback(
    () =>
      request('/admin/geography')
        .then((data) => setTree(data.districts))
        .catch((err) => setError(err.message)),
    [request],
  );

  useEffect(() => {
    load();
  }, [load]);

  // The units of each column: districts, then the children of each chosen unit.
  const columns = [];
  let units = tree ?? [];
  for (const [index, def] of LEVELS.entries()) {
    columns.push({ ...def, units, parent: index === 0 ? null : columns[index - 1].chosen });
    const chosen = units.find((u) => u.id === path[index]);
    columns[index].chosen = chosen ?? null;
    if (!chosen || !def.children) break;
    units = chosen[def.children];
  }

  async function run(action, message) {
    setError(null);
    setNotice(null);
    try {
      await action();
      setNotice(message);
      await load();
      return true;
    } catch (err) {
      setError(err.message);
      return false;
    } finally {
      setDialog(null);
    }
  }

  const add = (column, name) =>
    run(
      () => request(`/admin/geography/${column.level}`, { method: 'POST', body: { name, parentId: column.parent?.id } }),
      `${name} added.`,
    );
  const rename = (column, unit, name) =>
    run(() => request(`/admin/geography/${column.level}/${unit.id}`, { method: 'PATCH', body: { name } }), `Renamed to ${name}.`);
  const remove = (column, unit) =>
    run(async () => {
      await request(`/admin/geography/${column.level}/${unit.id}`, { method: 'DELETE' });
      setPath((p) => p.slice(0, LEVELS.findIndex((l) => l.level === column.level)));
    }, `${unit.name} deleted.`);

  return (
    <>
      <h1>Areas</h1>
      <p className="muted">
        The district, tehsil, Union Council and area structure. Choose a unit to see the units under it. LHWs and
        supervisors are given areas from here. A unit can be deleted only when nothing uses it any more.
      </p>
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      {notice && (
        <p className="notice" role="status">
          {notice}
        </p>
      )}
      {tree && (
        <div className="geography">
          {columns.map((column, index) => (
            <section key={column.level} className="geography-column" aria-label={column.title}>
              <h2>{column.title}</h2>
              {column.parent && <p className="muted">in {column.parent.name}</p>}
              {column.units.length === 0 && <p className="muted">None yet.</p>}
              <ul>
                {column.units.map((unit) => (
                  <li key={unit.id} className={path[index] === unit.id ? 'chosen' : undefined}>
                    {column.children ? (
                      <button type="button" className="link-button unit-name" onClick={() => setPath([...path.slice(0, index), unit.id])}>
                        {unit.name}
                      </button>
                    ) : (
                      <span className="unit-name">
                        {unit.name}
                        <span className="muted"> · {plural(unit.lhws, 'LHW')}, {plural(unit.supervisors, 'supervisor')}</span>
                      </span>
                    )}
                    <span className="unit-actions">
                      <button type="button" className="secondary" aria-label={`Rename ${unit.name}`} onClick={() => setDialog({ type: 'rename', column, unit })}>
                        Rename
                      </button>
                      <button type="button" className="secondary" aria-label={`Delete ${unit.name}`} onClick={() => setDialog({ type: 'delete', column, unit })}>
                        Delete
                      </button>
                    </span>
                  </li>
                ))}
              </ul>
              <AddForm label={column.label} onAdd={(name) => add(column, name)} />
            </section>
          ))}
        </div>
      )}

      {dialog?.type === 'rename' && (
        <Dialog title={`Rename ${dialog.unit.name}`}>
          <RenameForm unit={dialog.unit} onRename={(name) => rename(dialog.column, dialog.unit, name)} onCancel={() => setDialog(null)} />
        </Dialog>
      )}
      {dialog?.type === 'delete' && (
        <Dialog title={`Delete ${dialog.unit.name}?`}>
          <p>
            The {dialog.column.label} is removed from the lists. Records already linked to it keep the link. Creating a{' '}
            {dialog.column.label} with the same name here later brings it back.
          </p>
          <div className="actions">
            <button type="button" className="danger" onClick={() => remove(dialog.column, dialog.unit)}>
              Delete
            </button>
            <button type="button" className="secondary" onClick={() => setDialog(null)}>
              Cancel
            </button>
          </div>
        </Dialog>
      )}
    </>
  );
}
