// M2 FE-3: the estimated distance from the LHW to a home, from their GPS
// positions, with no maps or internet: the great-circle (haversine) distance.
// It is a straight line, so the walk is usually longer.
import 'dart:math';

const double _earthRadiusKm = 6371.0088;

double _radians(double degrees) => degrees * pi / 180;

/// Kilometres between two positions in degrees.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _radians(lat2 - lat1);
  final dLon = _radians(lon2 - lon1);
  final a = pow(sin(dLat / 2), 2) + cos(_radians(lat1)) * cos(_radians(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * _earthRadiusKm * asin(min(1, sqrt(a)));
}
