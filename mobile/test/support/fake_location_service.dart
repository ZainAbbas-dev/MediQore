import 'package:mediqore/location/location_service.dart';

/// A GPS for tests: answers [result] and records what the screens asked for.
class FakeLocationService implements LocationService {
  LocationResult result = const LocationResult.found(LocationFix(latitude: 33.684412, longitude: 73.047912, accuracyMetres: 8));
  int calls = 0;
  final List<LocationProblem> openedSettings = [];

  @override
  Future<LocationResult> current() async {
    calls++;
    return result;
  }

  @override
  Future<void> openSettings(LocationProblem problem) async => openedSettings.add(problem);
}
