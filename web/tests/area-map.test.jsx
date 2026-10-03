import { render } from '@testing-library/react';
import AreaMap from '../src/components/AreaMap';

// Leaflet itself, in jsdom: the map renders and draws one point per located household.
describe('AreaMap', () => {
  it('renders an empty map of Pakistan', () => {
    const { container } = render(<AreaMap households={[]} />);

    expect(container.querySelector('.leaflet-container')).toBeInTheDocument();
    expect(container.querySelectorAll('path.leaflet-interactive')).toHaveLength(0);
  });

  it('draws households that have GPS and skips those without', () => {
    const households = [
      { id: '1', latitude: 33.68, longitude: 73.04, village: 'A', householdNumber: 'H-1' },
      { id: '2', latitude: 33.69, longitude: 73.05, village: 'B', householdNumber: 'H-2' },
      { id: '3', latitude: null, longitude: null, village: 'C', householdNumber: 'H-3' },
    ];

    const { container } = render(<AreaMap households={households} />);

    expect(container.querySelectorAll('path.leaflet-interactive')).toHaveLength(2);
  });
});
