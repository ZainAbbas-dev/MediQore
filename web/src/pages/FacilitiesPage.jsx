// M10 FE-3: hospitals and referral centres, for admins. Each serves a district,
// optionally one area in it, with its phone and GPS position. The LHW app will
// use them to find the nearest hospital offline (M5 FE-1, Phase 2).
import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../auth/context';
import Dialog from '../components/Dialog';

const KINDS = {
  hospitals: {
    title: 'Hospitals',
    one: 'hospital',
    typeLabel: 'Type (optional)',
    typePlaceholder: 'for example DHQ, THQ or RHC',
    typeRequired: false,
  },
  'referral-centres': {
    title: 'Referral centres',
    one: 'referral centre',
    typeLabel: 'Type',
    typePlaceholder: 'for example Nutrition Rehabilitation Centre',
    typeRequired: true,
  },
};

// The district's areas, from the geography tree.
function areasOf(district) {
  if (!district) return [];
  return district.tehsils.flatMap((t) => t.unionCouncils.flatMap((uc) => uc.areas.map((a) => ({ ...a, label: `${t.name} › ${uc.name} › ${a.name}` }))));
}

function FacilityForm({ kind, districts, facility, onSubmit, onCancel }) {
  const def = KINDS[kind];
  const [values, setValues] = useState({
    name: facility?.name ?? '',
    type: facility?.type ?? '',
    districtId: facility?.district.id ?? '',
    areaId: facility?.area?.id ?? '',
    address: facility?.address ?? '',
    phone: facility?.phone ?? '',
    latitude: facility?.latitude ?? '',
    longitude: facility?.longitude ?? '',
  });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const set = (field) => (e) => setValues((v) => ({ ...v, [field]: e.target.value, ...(field === 'districtId' ? { areaId: '' } : {}) }));
  const areas = areasOf(districts.find((d) => d.id === values.districtId));

  async function handleSubmit(event) {
    event.preventDefault();
    if ((values.latitude === '') !== (values.longitude === '')) {
      setError('Give both latitude and longitude, or neither.');
      return;
    }
    setBusy(true);
    setError(null);
    const number = (text) => (text === '' ? null : Number(text));
    try {
      await onSubmit({
        name: values.name.trim(),
        type: values.type.trim() || null,
        districtId: values.districtId,
        areaId: values.areaId || null,
        address: values.address.trim() || null,
        phone: values.phone.trim() || null,
        latitude: number(values.latitude),
        longitude: number(values.longitude),
      });
    } catch (err) {
      setError(err.code === 'VALIDATION_ERROR' ? 'Check the name, phone number and GPS position.' : err.message);
      setBusy(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="stack">
      <label htmlFor="facility-name">Name</label>
      <input id="facility-name" value={values.name} onChange={set('name')} required minLength={2} maxLength={150} />
      <label htmlFor="facility-type">{def.typeLabel}</label>
      <input id="facility-type" value={values.type} onChange={set('type')} required={def.typeRequired} placeholder={def.typePlaceholder} maxLength={100} />
      <label htmlFor="facility-district">District</label>
      <select id="facility-district" value={values.districtId} onChange={set('districtId')} required>
        <option value="">Choose a district</option>
        {districts.map((d) => (
          <option key={d.id} value={d.id}>
            {d.name}
          </option>
        ))}
      </select>
      <label htmlFor="facility-area">Area (optional)</label>
      <select id="facility-area" value={values.areaId} onChange={set('areaId')} disabled={!values.districtId}>
        <option value="">The whole district</option>
        {areas.map((a) => (
          <option key={a.id} value={a.id}>
            {a.label}
          </option>
        ))}
      </select>
      <label htmlFor="facility-address">Address (optional)</label>
      <input id="facility-address" value={values.address} onChange={set('address')} maxLength={300} />
      <label htmlFor="facility-phone">Phone number (optional)</label>
      <input id="facility-phone" value={values.phone} onChange={set('phone')} placeholder="051 xxxxxxx" />
      <div className="coordinates">
        <div className="stack">
          <label htmlFor="facility-latitude">Latitude (optional)</label>
          <input id="facility-latitude" type="number" step="0.000001" min="-90" max="90" value={values.latitude} onChange={set('latitude')} />
        </div>
        <div className="stack">
          <label htmlFor="facility-longitude">Longitude (optional)</label>
          <input id="facility-longitude" type="number" step="0.000001" min="-180" max="180" value={values.longitude} onChange={set('longitude')} />
        </div>
      </div>
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      <div className="actions">
        <button type="submit" disabled={busy}>
          {facility ? 'Save changes' : `Add ${def.one}`}
        </button>
        <button type="button" className="secondary" onClick={onCancel}>
          Cancel
        </button>
      </div>
    </form>
  );
}

export default function FacilitiesPage() {
  const { request } = useAuth();
  const [kind, setKind] = useState('hospitals');
  const [districtId, setDistrictId] = useState('');
  const [facilities, setFacilities] = useState(null);
  const [districts, setDistricts] = useState([]);
  const [error, setError] = useState(null);
  const [dialog, setDialog] = useState(null); // { type, facility? }
  const def = KINDS[kind];

  const load = useCallback(() => {
    const query = districtId ? `?districtId=${districtId}` : '';
    return request(`/admin/${kind}${query}`)
      .then((data) => {
        setFacilities(data.facilities);
        setError(null);
      })
      .catch((err) => setError(err.message));
  }, [request, kind, districtId]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    request('/admin/geography')
      .then((data) => setDistricts(data.districts))
      .catch((err) => setError(err.message));
  }, [request]);

  const close = () => setDialog(null);

  async function create(values) {
    await request(`/admin/${kind}`, { method: 'POST', body: values });
    close();
    load();
  }

  async function save(facility, values) {
    await request(`/admin/${kind}/${facility.id}`, { method: 'PATCH', body: values });
    close();
    load();
  }

  async function remove(facility) {
    try {
      await request(`/admin/${kind}/${facility.id}`, { method: 'DELETE' });
      load();
    } catch (err) {
      setError(err.message);
    } finally {
      close();
    }
  }

  return (
    <>
      <div className="page-header">
        <h1>Hospitals and referral centres</h1>
        <button type="button" onClick={() => setDialog({ type: 'create' })}>
          Add {def.one}
        </button>
      </div>
      <div className="tabs" role="tablist" aria-label="Kind of facility">
        {Object.entries(KINDS).map(([value, { title }]) => (
          <button
            key={value}
            type="button"
            role="tab"
            aria-selected={kind === value}
            className={kind === value ? undefined : 'secondary'}
            onClick={() => {
              setKind(value);
              setFacilities(null);
            }}
          >
            {title}
          </button>
        ))}
      </div>
      <div className="toolbar">
        <label htmlFor="facility-district-filter">District</label>
        <select id="facility-district-filter" value={districtId} onChange={(e) => setDistrictId(e.target.value)}>
          <option value="">All districts</option>
          {districts.map((d) => (
            <option key={d.id} value={d.id}>
              {d.name}
            </option>
          ))}
        </select>
      </div>
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      {facilities && facilities.length === 0 && <p className="muted">No {def.one}s yet.</p>}
      {facilities && facilities.length > 0 && (
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th>District</th>
                <th>Area</th>
                <th>Phone</th>
                <th>GPS</th>
                <th aria-label="Actions" />
              </tr>
            </thead>
            <tbody>
              {facilities.map((f) => (
                <tr key={f.id}>
                  <td>
                    {f.name}
                    {f.address && <div className="muted">{f.address}</div>}
                  </td>
                  <td>{f.type || '–'}</td>
                  <td>{f.district.name}</td>
                  <td>{f.area?.name ?? 'Whole district'}</td>
                  <td className="nowrap">{f.phone || '–'}</td>
                  <td className="nowrap">{f.latitude !== null ? `${f.latitude}, ${f.longitude}` : 'Not recorded'}</td>
                  <td className="row-actions">
                    <button type="button" className="secondary" aria-label={`Edit ${f.name}`} onClick={() => setDialog({ type: 'edit', facility: f })}>
                      Edit
                    </button>
                    <button type="button" className="secondary" aria-label={`Delete ${f.name}`} onClick={() => setDialog({ type: 'delete', facility: f })}>
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {dialog?.type === 'create' && (
        <Dialog title={`Add ${def.one}`}>
          <FacilityForm kind={kind} districts={districts} onSubmit={create} onCancel={close} />
        </Dialog>
      )}
      {dialog?.type === 'edit' && (
        <Dialog title={`Edit ${dialog.facility.name}`}>
          <FacilityForm kind={kind} districts={districts} facility={dialog.facility} onSubmit={(v) => save(dialog.facility, v)} onCancel={close} />
        </Dialog>
      )}
      {dialog?.type === 'delete' && (
        <Dialog title={`Delete ${dialog.facility.name}?`}>
          <p>It is removed from the lists and, later, from the LHWs&apos; phones at their next sync.</p>
          <div className="actions">
            <button type="button" className="danger" onClick={() => remove(dialog.facility)}>
              Delete
            </button>
            <button type="button" className="secondary" onClick={close}>
              Cancel
            </button>
          </div>
        </Dialog>
      )}
    </>
  );
}
