import { useState } from 'react';

const areaLabel = (a) => `${a.district} › ${a.tehsil} › ${a.unionCouncil} › ${a.name}`;

// Picks several areas, for example a supervisor's (M10 FE-3). A search box
// narrows the list; chosen areas stay listed first.
export default function AreaChecklist({ areas, selected, onChange }) {
  const [filter, setFilter] = useState('');
  const text = filter.trim().toLowerCase();
  const chosen = areas.filter((a) => selected.includes(a.id));
  const others = areas.filter((a) => !selected.includes(a.id) && (!text || areaLabel(a).toLowerCase().includes(text)));

  const toggle = (id) => onChange(selected.includes(id) ? selected.filter((x) => x !== id) : [...selected, id]);

  return (
    <fieldset className="area-checklist">
      <legend>Areas ({selected.length} chosen)</legend>
      <input
        type="search"
        aria-label="Find an area"
        placeholder="Find a district, tehsil, Union Council or area"
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
      />
      <div className="area-checklist-list">
        {[...chosen, ...others].map((a) => (
          <label key={a.id}>
            <input type="checkbox" checked={selected.includes(a.id)} onChange={() => toggle(a.id)} />
            {areaLabel(a)}
          </label>
        ))}
        {chosen.length + others.length === 0 && <p className="muted">No area matches.</p>}
      </div>
    </fieldset>
  );
}
