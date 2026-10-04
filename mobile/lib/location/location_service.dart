// M2 FE-3: the home's GPS position at registration. GPS works without the
// internet; a first fix without mobile data can take a minute, so the wait is
// long. Screens use [LocationService] so tests can replace the phone's GPS.
import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// A position and how far off it may be, in metres.
class LocationFix {
  const LocationFix({required this.latitude, required this.longitude, required this.accuracyMetres});

  final double latitude;
  final double longitude;
  final double accuracyMetres;
}

/// Why no position could be found.
enum LocationProblem {
  /// The phone's location setting is off.
  serviceOff,

  /// The LHW said no to the permission request; asking again is possible.
  denied,

  /// The permission is off for good; only the phone's settings can turn it on.
  deniedForever,

  /// No fix in time, for example indoors.
  unavailable,
}

/// A fix, or the problem that prevented one.
class LocationResult {
  const LocationResult.found(LocationFix this.fix) : problem = null;
  const LocationResult.failed(LocationProblem this.problem) : fix = null;

  final LocationFix? fix;
  final LocationProblem? problem;
}

abstract interface class LocationService {
  /// Asks for permission if needed, then waits for one position.
  Future<LocationResult> current();

  /// Opens the phone's settings for [problem]: the location setting, or the
  /// app's permissions.
  Future<void> openSettings(LocationProblem problem);
}

/// The phone's GPS, through the geolocator package (roadmap, M2 FE-3).
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService({this.timeLimit = const Duration(seconds: 60)});

  final Duration timeLimit;

  @override
  Future<LocationResult> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) return const LocationResult.failed(LocationProblem.serviceOff);

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return const LocationResult.failed(LocationProblem.denied);
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.failed(LocationProblem.deniedForever);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeLimit),
      );
      return LocationResult.found(
        LocationFix(latitude: position.latitude, longitude: position.longitude, accuracyMetres: position.accuracy),
      );
    } on LocationServiceDisabledException {
      return const LocationResult.failed(LocationProblem.serviceOff);
    } on PermissionDeniedException {
      return const LocationResult.failed(LocationProblem.denied);
    } on TimeoutException {
      return const LocationResult.failed(LocationProblem.unavailable);
    }
  }

  @override
  Future<void> openSettings(LocationProblem problem) async {
    if (problem == LocationProblem.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
