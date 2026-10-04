import 'auth/password_key.dart';
import 'auth/session.dart';
import 'data/app_database.dart';
import 'data/database_opener.dart';
import 'data/household_repository.dart';
import 'data/local_data.dart';
import 'data/patient_repository.dart';
import 'location/location_service.dart';
import 'settings/app_settings.dart';
import 'sync/sync_api.dart';
import 'sync/sync_service.dart';

/// The app's long-lived objects, created once in main() and handed to the
/// screens that need them. Tests pass an in-memory database opener, a fake API
/// and, by default, settings that start in Urdu and are not saved.
///
/// The database and everything that uses it exist only while the app is
/// unlocked (M3 FE-2): [db], [households], [patients] and [sync] throw a
/// [StateError] while it is locked. Screens that use them are closed on lock.
class AppServices {
  AppServices({
    required this.opener,
    required this.api,
    AppSettings? settings,
    Duration? autoLockAfter,
    int? passwordIterations,
    this.location = const GeolocatorLocationService(),
  }) : settings = settings ?? AppSettings() {
    session = Session(
      opener: opener,
      api: api,
      settings: this.settings,
      autoLockAfter: autoLockAfter ?? const Duration(minutes: 5),
      passwordIterations: passwordIterations ?? PasswordKey.defaultIterations,
    );
  }

  /// Real services on the phone. [settings] come from [AppSettings.load].
  factory AppServices.onDevice({required AppSettings settings}) =>
      AppServices(opener: EncryptedDatabaseOpener(), api: SyncApi(), settings: settings);

  final DatabaseOpener opener;
  final SyncApi api;
  final AppSettings settings;

  /// The phone's GPS, for the home location (M2 FE-3).
  final LocationService location;

  /// Who is signed in, the tokens for sync (M1 FE-2) and the open database.
  late final Session session;

  /// The open database and its repositories (M3 FE-2).
  LocalData get data => session.data ?? (throw StateError('The app is locked: sign in to open the database'));

  AppDatabase get db => data.db;
  HouseholdRepository get households => data.households;

  /// Registered women and their pregnancy files (M2).
  PatientRepository get patients => data.patients;
  SyncService get sync => data.sync;

  /// Locks the session and closes the database, for example at the end of a test.
  Future<void> dispose() async {
    session.lock(null);
    await session.closed;
    await opener.dispose();
  }
}
