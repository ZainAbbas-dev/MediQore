import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mediqore/location/location_service.dart';

void main() {
  final now = DateTime.utc(2026, 11, 27, 12);
  Position position(DateTime timestamp) => Position(
    longitude: 73.048,
    latitude: 33.684,
    timestamp: timestamp,
    accuracy: 8,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  test('keeps a recent GPS position and its reported accuracy', () {
    final result = LocationResult.fromPosition(position(now.subtract(const Duration(seconds: 2))), now: now);
    expect(result.fix!.latitude, 33.684);
    expect(result.fix!.longitude, 73.048);
    expect(result.fix!.accuracyMetres, 8);
  });

  test('rejects a stale position so an old location is not saved to the home', () {
    final result = LocationResult.fromPosition(position(now.subtract(const Duration(minutes: 2))), now: now);
    expect(result.fix, isNull);
    expect(result.problem, LocationProblem.unavailable);
  });
}
