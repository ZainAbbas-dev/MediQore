import { useEffect, useState } from 'react';
import { useAuth } from '../auth/context';
import AreaChecklist from '../components/AreaChecklist';
import Dialog from '../components/Dialog';

const SECTIONS = {
  contacts: { path: '/area-config/escalation-contacts', title: 'Escalation contacts', item: 'escalation contact' },
  campaigns: { path: '/area-config/campaign-rounds', title: 'Polio campaign rounds', item: 'campaign round' },
};

const areaLabel = ({ district, tehsil, unionCouncil, name }) => `${district} › ${tehsil} › ${unionCouncil} › ${name}`;

function FormActions({ error, busy, label, onCancel }) {
  return (
    <>
      {error && <p className="error" role="alert">{error}</p>}
      <div className="actions">
        <button type="submit" disabled={busy}>{busy ? 'Saving…' : label}</button>
        <button type="button" className="secondary" disabled={busy} onClick={onCancel}>Cancel</button>
      </div>
    </>
  );
}

function ContactForm({ contact, areas, supervisors, onSave, onCancel }) {
  const [values, setValues] = useState({
    areaId: contact?.area.id ?? '',
    supervisorUserId: contact?.supervisorUserId ?? '',
    supervisorPhone: contact?.supervisorPhone ?? '',
    secondaryName: contact?.secondaryName ?? '',
    secondaryPhone: contact?.secondaryPhone ?? '',
    escalateAfterMinutes: contact?.escalateAfterMinutes ?? 15,
  });
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  const setField = (field) => (event) => {
    const { value } = event.target;
    setValues((previous) => ({ ...previous, [field]: value }));
  };
  const availableSupervisors = supervisors.filter((item) => item.areaId === values.areaId);
  const existingSupervisorMissing = values.supervisorUserId && !availableSupervisors.some(
    (item) => item.userId === values.supervisorUserId,
  );

  function chooseArea(event) {
    const { value } = event.target;
    setValues((previous) => ({ ...previous, areaId: value, supervisorUserId: '', supervisorPhone: '' }));
  }

  function chooseSupervisor(event) {
    const { value } = event.target;
    const supervisor = availableSupervisors.find((item) => item.userId === value);
    setValues((previous) => ({
      ...previous,
      supervisorUserId: value,
      supervisorPhone: supervisor ? supervisor.phone ?? '' : previous.supervisorPhone,
    }));
  }

  async function submit(event) {
    event.preventDefault();
    const { areaId, supervisorUserId, supervisorPhone, secondaryName, secondaryPhone, escalateAfterMinutes } = values;
    if (Boolean(secondaryName.trim()) !== Boolean(secondaryPhone.trim())) {
      setError('Enter both the secondary contact name and phone.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await onSave(areaId, {
        supervisorUserId: supervisorUserId || null,
        supervisorPhone: supervisorPhone.trim(),
        secondaryName: secondaryName.trim() || null,
        secondaryPhone: secondaryPhone.trim() || null,
        escalateAfterMinutes: Number(escalateAfterMinutes),
      });
    } catch (err) {
      setError(err.message === 'Request validation failed' ? 'Check the phone numbers and escalation time.' : err.message);
      setBusy(false);
    }
  }

  return (
    <form className="stack" onSubmit={submit}>
      {contact ? (
        <p>{areaLabel(contact.area)}</p>
      ) : (
        <>
          <label htmlFor="escalation-area">Area</label>
          <select id="escalation-area" required value={values.areaId} onChange={chooseArea}>
            <option value="">Choose an area</option>
            {areas.map((area) => <option key={area.id} value={area.id}>{areaLabel(area)}</option>)}
          </select>
        </>
      )}
      <label htmlFor="escalation-supervisor">Assigned supervisor (optional)</label>
      <select id="escalation-supervisor" disabled={!values.areaId} value={values.supervisorUserId} onChange={chooseSupervisor}>
        <option value="">Enter a phone number manually</option>
        {existingSupervisorMissing && <option value={values.supervisorUserId}>Previously assigned supervisor</option>}
        {availableSupervisors.map(({ userId, fullName }) => <option key={userId} value={userId}>{fullName}</option>)}
      </select>
      <label htmlFor="escalation-supervisor-phone">Supervisor phone</label>
      <input id="escalation-supervisor-phone" type="tel" required maxLength={24} value={values.supervisorPhone} onChange={setField('supervisorPhone')} />
      <label htmlFor="escalation-secondary-name">Secondary contact name (optional)</label>
      <input id="escalation-secondary-name" maxLength={150} value={values.secondaryName} onChange={setField('secondaryName')} />
      <label htmlFor="escalation-secondary-phone">Secondary contact phone (optional)</label>
      <input id="escalation-secondary-phone" type="tel" maxLength={24} value={values.secondaryPhone} onChange={setField('secondaryPhone')} />
      <label htmlFor="escalation-minutes">Escalate after (minutes)</label>
      <input id="escalation-minutes" type="number" min="1" max="32767" step="1" required
        value={values.escalateAfterMinutes} onChange={setField('escalateAfterMinutes')} />
      <FormActions error={error} busy={busy} label="Save contact" onCancel={onCancel} />
    </form>
  );
}

function RoundForm({ round, areas, onSave, onCancel }) {
  const [name, setName] = useState(round?.name ?? '');
  const [startsOn, setStartsOn] = useState(round?.startsOn ?? '');
  const [endsOn, setEndsOn] = useState(round?.endsOn ?? '');
  const [areaIds, setAreaIds] = useState(() => round?.areas.map(({ id }) => id) ?? []);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  async function submit(event) {
    event.preventDefault();
    if (!areaIds.length) {
      setError('Choose at least one target area.');
      return;
    }
    if (endsOn < startsOn) {
      setError('The end date must be on or after the start date.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await onSave({ name: name.trim(), startsOn, endsOn, areaIds });
    } catch (err) {
      setError(err.message === 'Request validation failed' ? 'Check the round name, dates and target areas.' : err.message);
      setBusy(false);
    }
  }

  return (
    <form className="stack" onSubmit={submit}>
      <label htmlFor="round-name">Round name</label>
      <input id="round-name" required minLength={2} maxLength={150} value={name} onChange={(event) => setName(event.target.value)} />
      <div className="coordinates">
        <div className="stack">
          <label htmlFor="round-starts">Start date</label>
          <input id="round-starts" type="date" required value={startsOn} onChange={(event) => setStartsOn(event.target.value)} />
        </div>
        <div className="stack">
          <label htmlFor="round-ends">End date</label>
          <input id="round-ends" type="date" required value={endsOn} onChange={(event) => setEndsOn(event.target.value)} />
        </div>
      </div>
      <AreaChecklist areas={areas} selected={areaIds} onChange={setAreaIds} />
      <FormActions error={error} busy={busy} label="Save round" onCancel={onCancel} />
    </form>
  );
}

function RowActions({ item, label, onEdit, onDelete }) {
  return (
    <td className="row-actions">
      <button type="button" className="secondary" aria-label={`Edit ${label}`} onClick={() => onEdit(item)}>Edit</button>
      <button type="button" className="secondary" aria-label={`Delete ${label}`} onClick={() => onDelete(item)}>Delete</button>
    </td>
  );
}

function ContactTable({ contacts, onEdit, onDelete }) {
  return (
    <div className="table-scroll">
      <table>
        <thead>
          <tr><th>Area</th><th>Supervisor phone</th><th>Secondary contact</th><th>Escalation time</th><th aria-label="Actions" /></tr>
        </thead>
        <tbody>
          {contacts.map((contact) => (
            <tr key={contact.id}>
              <th scope="row">
                {contact.area.name}
                <div className="muted">{contact.area.district} › {contact.area.tehsil} › {contact.area.unionCouncil}</div>
              </th>
              <td className="nowrap">{contact.supervisorPhone}</td>
              <td>
                {contact.secondaryName ?? '—'}
                {contact.secondaryPhone && <div className="muted">{contact.secondaryPhone}</div>}
              </td>
              <td className="nowrap">{contact.escalateAfterMinutes} min</td>
              <RowActions item={contact} label={`contact for ${contact.area.name}`} onEdit={onEdit} onDelete={onDelete} />
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

const dateFormat = new Intl.DateTimeFormat('en-PK', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' });

function CampaignTable({ rounds, onEdit, onDelete }) {
  return (
    <div className="table-scroll">
      <table>
        <thead>
          <tr><th>Round</th><th>Dates</th><th>Target areas</th><th aria-label="Actions" /></tr>
        </thead>
        <tbody>
          {rounds.map((round) => (
            <tr key={round.id}>
              <th scope="row">{round.name}</th>
              <td className="nowrap">
                <time dateTime={round.startsOn}>{dateFormat.format(new Date(round.startsOn))}</time>
                {' – '}
                <time dateTime={round.endsOn}>{dateFormat.format(new Date(round.endsOn))}</time>
              </td>
              <td>
                {round.areas.map((area) => <div key={area.id} title={areaLabel(area)}>{area.name}</div>)}
              </td>
              {round.editable
                ? <RowActions item={round} label={round.name} onEdit={onEdit} onDelete={onDelete} />
                : <td className="muted">Shared round</td>}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function DeleteForm({ message, onDelete, onCancel }) {
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  async function submit(event) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await onDelete();
    } catch (err) {
      setError(err.message);
      setBusy(false);
    }
  }

  return (
    <form className="stack" onSubmit={submit}>
      <p>{message}</p>
      {error && <p role="alert" className="error">{error}</p>}
      <div className="actions">
        <button type="submit" className="danger" disabled={busy}>Delete</button>
        <button type="button" className="secondary" disabled={busy} onClick={onCancel}>Cancel</button>
      </div>
    </form>
  );
}

function AreaSection({ section }) {
  const { request } = useAuth();
  const { path, title, item } = SECTIONS[section];
  const isContacts = section === 'contacts';
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [dialog, setDialog] = useState(null);
  const [revision, setRevision] = useState(0);

  useEffect(() => {
    let ignore = false;
    Promise.all([request(path), request(`${path}/options`)])
      .then(([records, options]) => {
        if (!ignore) {
          setData({ records: records[isContacts ? 'contacts' : 'rounds'], ...options });
          setError(null);
        }
      })
      .catch((err) => {
        if (!ignore) setError(err.message);
      });
    return () => { ignore = true; };
  }, [request, path, isContacts, revision]);

  const close = () => setDialog(null);
  const retry = () => setRevision((current) => current + 1);
  const edit = (record) => setDialog({ action: 'edit', record });
  const remove = (record) => setDialog({ action: 'delete', record });
  const selected = dialog?.record;
  const selectedLabel = isContacts ? selected?.area.name : selected?.name;
  const availableAreas = (data?.areas ?? []).filter(
    (area) => !isContacts || !data.records.some((record) => record.area.id === area.id),
  );

  async function mutate(url, method, body) {
    await request(url, { method, body });
    close();
    retry();
  }

  return (
    <>
      <div className="page-header">
        <h1>{title}</h1>
        <button type="button" disabled={!availableAreas.length} onClick={() => setDialog({ action: 'add' })}>Add {item}</button>
      </div>
      {error && (
        <div className="toolbar">
          <p role="alert" className="error">{error}</p>
          <button type="button" className="secondary" onClick={retry}>Retry</button>
        </div>
      )}
      {!data && !error && <p role="status" className="muted">Loading {title.toLowerCase()}…</p>}
      {data?.records.length === 0 && <p className="muted">No {title.toLowerCase()} are configured.</p>}
      {data?.records.length > 0 && (isContacts
        ? <ContactTable contacts={data.records} onEdit={edit} onDelete={remove} />
        : <CampaignTable rounds={data.records} onEdit={edit} onDelete={remove} />)}

      {dialog && dialog.action !== 'delete' && (
        <Dialog title={selected ? `Edit ${selectedLabel}` : `Add ${item}`}>
          {isContacts ? (
            <ContactForm contact={selected} areas={availableAreas} supervisors={data.supervisors}
              onSave={(areaId, values) => mutate(`${path}/${areaId}`, 'PUT', values)} onCancel={close} />
          ) : (
            <RoundForm round={selected} areas={data.areas}
              onSave={(values) => mutate(selected ? `${path}/${selected.id}` : path, selected ? 'PATCH' : 'POST', values)} onCancel={close} />
          )}
        </Dialog>
      )}
      {dialog?.action === 'delete' && (
        <Dialog title={`Delete ${selectedLabel}?`}>
          <DeleteForm message={isContacts
            ? 'The contact will be removed from this area’s phones the next time they sync.'
            : 'The round will be removed from its target areas the next time their phones sync.'}
          onDelete={() => mutate(`${path}/${isContacts ? selected.area.id : selected.id}`, 'DELETE')} onCancel={close} />
        </Dialog>
      )}
    </>
  );
}

export default function AreaConfigPage({ section }) {
  return <AreaSection key={section} section={section} />;
}
