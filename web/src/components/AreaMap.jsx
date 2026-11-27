// M10 FE-1: geographic map for the dashboard (Leaflet.js). P0-5 provides the
// map itself; households from Module 2 GPS are drawn as points.
import { useEffect, useMemo, useRef, useState } from 'react';
import { CircleMarker, MapContainer, TileLayer, Tooltip, useMap, useMapEvents } from 'react-leaflet';

// Whole of Pakistan when there is nothing to show.
const PAKISTAN_CENTER = [30.3753, 69.3451];
const PAKISTAN_ZOOM = 5;
const NO_HOUSEHOLDS = [];

// Fits the map to the points when they change, but not when an automatic
// refresh brings the same points again, so the user's zoom is kept.
function FitToPoints({ points }) {
  const map = useMap();
  const fitted = useRef(null);
  useEffect(() => {
    const key = points.map((p) => p.join(',')).join(';');
    if (key === fitted.current) return;
    fitted.current = key;
    if (points.length === 1) map.setView(points[0], 13);
    if (points.length > 1) map.fitBounds(points, { padding: [32, 32] });
  }, [map, points]);
  return null;
}

const COLORS = { red: '#b42318', yellow: '#926100', green: '#1e6b34', unknown: '#52736b' };

function HouseholdMarkers({ households }) {
  const map = useMap();
  const [zoom, setZoom] = useState(() => map.getZoom());
  useMapEvents({ zoomend: () => setZoom(map.getZoom()) });
  const groups = useMemo(() => {
    if (households.length < 25 || zoom >= 16) return households.map((h) => [h]);
    const cells = new Map();
    for (const home of households) {
      const { x, y } = map.project([home.latitude, home.longitude], zoom);
      const cell = `${Math.floor(x / 52)}:${Math.floor(y / 52)}`;
      if (!cells.has(cell)) cells.set(cell, []);
      cells.get(cell).push(home);
    }
    return [...cells.values()];
  }, [households, map, zoom]);

  return groups.map((group) => {
    const first = group[0];
    const center = ['latitude', 'longitude'].map((field) => group.reduce((sum, home) => sum + home[field], 0) / group.length);
    const level = ['red', 'yellow', 'green'].find((risk) => group.some((h) => h.riskLevel === risk));
    const multiple = group.length > 1;
    const label = multiple
      ? `${group.length} households${level ? ` · highest risk ${level}` : ''}`
      : [first.householdNumber, first.village, first.mapLabel || (level ? `Risk: ${level}` : 'Risk not assessed')].filter(Boolean).join(' · ');
    return (
      <CircleMarker
        key={first.id}
        center={center}
        radius={multiple ? 15 : 8}
        pathOptions={{ color: COLORS[level] ?? COLORS.unknown, fillOpacity: 0.65 }}
        eventHandlers={multiple ? { click: () => map.fitBounds(group.map((h) => [h.latitude, h.longitude]), { padding: [32, 32], maxZoom: 16 }) } : undefined}
      >
        <Tooltip permanent={multiple}>{label}</Tooltip>
      </CircleMarker>
    );
  });
}

export default function AreaMap({ households = NO_HOUSEHOLDS, facilities = NO_HOUSEHOLDS }) {
  const located = useMemo(
    () => households.filter((h) => Number.isFinite(h.latitude) && Number.isFinite(h.longitude)),
    [households],
  );
  const points = useMemo(
    () => (located.length ? located : facilities).map((h) => [h.latitude, h.longitude]),
    [located, facilities],
  );

  return (
    <MapContainer center={PAKISTAN_CENTER} zoom={PAKISTAN_ZOOM} className="area-map" scrollWheelZoom={false}>
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <HouseholdMarkers households={located} />
      {facilities.map((facility) => (
        <CircleMarker key={facility.id} center={[facility.latitude, facility.longitude]} radius={7}
          pathOptions={{ color: '#245d99', fillOpacity: 0.8, dashArray: '3 2' }}>
          <Tooltip>{facility.name} · {facility.type ?? 'Referral facility'}</Tooltip>
        </CircleMarker>
      ))}
      <FitToPoints points={points} />
    </MapContainer>
  );
}
