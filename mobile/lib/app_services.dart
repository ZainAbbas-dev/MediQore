import 'auth/password_key.dart';
import 'auth/session.dart';
import 'data/app_database.dart';
import 'data/household_repository.dart';
import 'data/patient_repository.dart';
import 'location/location_service.dart';
import 'settings/app_settings.dart';
import 'sync/sync_api.dart';
import 'sync/sync_service.dart';

/// The app's long-lived objects, created once in main() and handed to the
/// screens that need them. Tests pass an in-memory database, a fake API and,
/// by default, settings that start in Urdu and are not saved.
class AppServices {
  factory AppServices({
    required AppDatabase db,
    required SyncApi api,
    AppSettings? settings,
    Duration? autoLockAfter,
    int? passwordIterations,
    LocationService location = const GeolocatorLocationService(),
  }) {
    final s = settings ?? AppSettings();
    final sync = SyncService(db: db, api: api, deviceId: s.deviceId);
    return AppServices._(
      db: db,
      api: api,
      settings: s,
      households: HouseholdRepository(db),
      patients: PatientRepository(db),
      location: location,
      sync: sync,
      session: Session(
        db: db,
        api: api,
        sync: sync,
        settings: s,
        autoLockAfter: autoLockAfter ?? const Duration(minutes: 5),
        passwordIterations: passwordIterations ?? PasswordKey.defaultIterations,
      ),
    );
  }

  AppServices._({
    required this.db,
    required this.api,
    required this.settings,
    required this.households,
    required this.patients,
    required this.location,
    required this.sync,
    required this.session,
  });

  /// Real services on the phone. [settings] come from [AppSettings.load].
  factory AppServices.onDevice({required AppSettings settings}) =>
      AppServices(db: AppDatabase.onDevice(), api: SyncApi(), settings: settings);

  final AppDatabase db;
  final SyncApi api;
  final AppSettings settings;
  final HouseholdRepository households;

  /// Registered women and their pregnancy files (M2).
  final PatientRepository patients;

  /// The phone's GPS, for the home location (M2 FE-3).
  final LocationService location;
  final SyncService sync;

  /// Who is signed in, and the tokens for sync (M1 FE-2).
  final Session session;
}
