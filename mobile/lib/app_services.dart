import 'package:connectivity_plus/connectivity_plus.dart';

import 'auth/pin.dart';
import 'auth/secure_store.dart';
import 'auth/session.dart';
import 'build_flags.dart';
import 'clinical/clinical_rules.dart';
import 'clinical/visit_ranges.dart';
import 'data/app_database.dart';
import 'data/database_opener.dart';
import 'data/household_repository.dart';
import 'data/local_data.dart';
import 'data/patient_repository.dart';
import 'data/visit_repository.dart';
import 'location/location_service.dart';
import 'phone/phone_dialer.dart';
import 'settings/app_settings.dart';
import 'sync/auto_sync.dart';
import 'sync/background_sync.dart';
import 'sync/background_tasks.dart';
import 'sync/sync_api.dart';
import 'sync/sync_gate.dart';
import 'sync/sync_service.dart';

/// The app's long-lived objects, created once in main() and handed to the
/// screens that need them. Tests pass an in-memory database opener, a fake API,
/// a secure store in memory and, by default, settings that start in Urdu and
/// are not saved.
///
/// The database and everything that uses it exist only while the app is
/// unlocked (M3 FE-2): [db], [households], [patients], [visits] and [sync]
/// throw a [StateError] while it is locked. Screens that use them are closed on
/// lock.
class AppServices {
  /// With [autoSync] false (tests), records sync only when asked.
  AppServices({
    required this.opener,
    required this.api,
    required this.secureStore,
    AppSettings? settings,
    Duration? autoLockAfter,
    int? pinIterations,
    DateTime Function()? clock,
    this.location = const GeolocatorLocationService(),
    this.dialer = const UrlLauncherDialer(),
    bool autoSync = true,
    this.clinicalRules,
    this.backgroundScheduler = const NoBackgroundScheduler(),
    SyncGate? syncGate,
    Stream<bool>? connectivity,
  }) : settings = settings ?? AppSettings() {
    session = Session(
      opener: opener,
      api: api,
      settings: this.settings,
      secure: secureStore,
      autoLockAfter: autoLockAfter ?? const Duration(minutes: 5),
      pinIterations: pinIterations ?? PinVerifier.defaultIterations,
      clock: clock,
    );
    this.autoSync = AutoSync(
      session: session,
      enabled: autoSync,
      settings: this.settings,
      gate: syncGate,
      scheduler: backgroundScheduler,
      connectivity: connectivity,
    );
  }

  /// Real services on the phone. [settings] come from [AppSettings.load] and
  /// [clinicalRules] from [ClinicalRules.load]. A test build uses the server address
  /// saved on the activation screen, if any.
  factory AppServices.onDevice({required AppSettings settings, required ClinicalRules clinicalRules}) => AppServices(
    opener: EncryptedDatabaseOpener(),
    api: SyncApi(baseUrl: apiAddressFor(settings)),
    secureStore: KeystoreSecureStore(),
    settings: settings,
    clinicalRules: clinicalRules,
    backgroundScheduler: const WorkmanagerScheduler(),
    syncGate: FileSyncGate(),
    connectivity: Connectivity().onConnectivityChanged.map(
      (results) => results.any((result) => result != ConnectivityResult.none),
    ),
  );

  final DatabaseOpener opener;
  final SyncApi api;
  final AppSettings settings;

  /// The Keystore-backed store for the database key, the activation secret,
  /// the refresh token and the PIN check (M1 FE-2, LI-8).
  final SecureStore secureStore;

  /// Opens the phone's dialer for the emergency call to the supervisor.
  final PhoneDialer dialer;

  /// The phone's GPS, for the home location (M2 FE-3).
  final LocationService location;

  /// The Clinical Rules Table bundled with the app, read at start (P0-11). The
  /// screens that use it read the file themselves when this is null.
  final ClinicalRules? clinicalRules;

  /// The visit form's range checks (M3 FE-1).
  VisitRanges? get visitRanges => clinicalRules?.visitRanges;

  /// Background sync with the app locked or closed (M3 FE-2); does nothing in tests.
  final BackgroundScheduler backgroundScheduler;

  /// Activation, the PIN lock, the tokens for sync (M1 FE-2) and the open database.
  late final Session session;

  /// Syncs on its own while the app is unlocked and online (M3 FE-2).
  late final AutoSync autoSync;

  /// The open database and its repositories (M3 FE-2).
  LocalData get data => session.data ?? (throw StateError('The app is locked: unlock it to open the database'));

  AppDatabase get db => data.db;
  HouseholdRepository get households => data.households;

  /// Registered women and their pregnancy files (M2).
  PatientRepository get patients => data.patients;

  /// Home visits (M3 FE-1).
  VisitRepository get visits => data.visits;
  SyncService get sync => data.sync;

  /// The API address in use.
  String get serverAddress => api.baseUrl;

  /// Points the app at another server and remembers it on the phone. Only the
  /// activation screen of a test build offers this (see `testBuild`).
  Future<void> setServerAddress(String address) async {
    api.baseUrl = address;
    await settings.setServerAddress(address);
  }

  /// Locks the session and closes the database, for example at the end of a test.
  Future<void> dispose() async {
    autoSync.dispose();
    session.lock(null);
    await session.closed;
    await opener.dispose();
  }
}
