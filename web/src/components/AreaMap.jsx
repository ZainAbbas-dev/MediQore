// M10 FE-1: geographic map for the dashboard (Leaflet.js). P0-5 provides the
// map itself; households from Module 2 GPS are drawn as points.
import { useEffect, useMemo, useRef } from 'react';
import { CircleMarker, MapContainer, TileLayer, Tooltip, useMap } from 'react-leaflet';

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

// households: [{ id, latitude, longitude, village, householdNumber }]
export default function AreaMap({ households = NO_HOUSEHOLDS }) {
  const located = useMemo(
    () => households.filter((h) => h.latitude !== null && h.longitude !== null),
    [households],
  );
  const points = useMemo(() => located.map((h) => [h.latitude, h.longitude]), [located]);

  return (
    <MapContainer center={PAKISTAN_CENTER} zoom={PAKISTAN_ZOOM} className="area-map" scrollWheelZoom={false}>
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      {located.map((h) => (
        <CircleMarker key={h.id} center={[h.latitude, h.longitude]} radius={8} pathOptions={{ color: '#00695c' }}>
          <Tooltip>{[h.householdNumber, h.village, h.registeredBy].filter(Boolean).join(' · ')}</Tooltip>
        </CircleMarker>
      ))}
      <FitToPoints points={points} />
    </MapContainer>
  );
}
