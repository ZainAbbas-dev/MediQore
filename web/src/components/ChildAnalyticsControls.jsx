import './ChildAnalyticsControls.css';

export function ChildAnalyticsControls({ selection, options, onChange, children, periodStart = true }) {
  const areas = options?.areas.filter((area) => !selection.districtId || selection.districtId === area.districtId) ?? [];
  const set = (name) => (event) => onChange({ [name]: event.target.value });

  return (
    <div className="header-controls child-analytics-filters" role="group" aria-label="Filters">
      <label className="field">
        District
        <select value={selection.districtId ?? ''} onChange={(e) => onChange({ districtId: e.target.value, areaId: '' })}>
          <option value="">All districts</option>
          {options?.districts.map((district) => <option key={district.id} value={district.id}>{district.name}</option>)}
        </select>
      </label>
      <label className="field">
        Area
        <select value={selection.areaId ?? ''} onChange={set('areaId')}>
          <option value="">All areas</option>
          {areas.map((area) => <option key={area.id} value={area.id}>{area.name}</option>)}
        </select>
      </label>
      {periodStart && (
        <label className="field">
          From date
          <input type="date" max={selection.endDate || undefined} value={selection.startDate ?? ''} onChange={set('startDate')} />
        </label>
      )}
      <label className="field">
        {periodStart ? 'Through date' : 'As of'}
        <input type="date" min={periodStart ? selection.startDate || undefined : undefined} value={selection.endDate ?? ''} onChange={set('endDate')} />
      </label>
      {children}
    </div>
  );
}

export function ChildPagination({ data, onPage }) {
  const pageCount = Math.ceil(data.total / data.limit);
  if (pageCount < 2 && data.page === 1) return null;
  return (
    <nav className="actions" aria-label="Pagination">
      <button className="secondary" type="button" disabled={data.page === 1} onClick={() => onPage(data.page - 1)}>
        Previous page
      </button>
      <span className="muted">Page {data.page}{data.page <= pageCount && ` of ${pageCount}`}</span>
      <button className="secondary" type="button" disabled={data.page >= pageCount} onClick={() => onPage(data.page + 1)}>
        Next page
      </button>
    </nav>
  );
}

export function ChildLoadStatus({ data, error }) {
  if (error) return <p className="error" role="alert">{error}</p>;
  if (!data) return <p className="muted" role="status">Loading…</p>;
  return null;
}
