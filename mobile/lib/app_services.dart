import 'auth/password_key.dart';
import 'build_flags.dart';
import 'auth/session.dart';
import 'clinical/visit_ranges.dart';
import 'data/app_database.dart';
import 'data/database_opener.dart';
import 'data/household_repository.dart';
import 'data/local_data.dart';
import 'data/patient_repository.dart';
import 'data/visit_repository.dart';
import 'location/location_service.dart';
import 'settings/app_settings.dart';
import 'sync/auto_sync.dart';
import 'sync/sync_api.dart';
import 'sync/sync_service.dart';
import 'voice/voice_guide.dart';

/// The app's long-lived objects, created once in main() and handed to the
/// screens that need them. Tests pass an in-memory database opener, a fake API
/// and, by default, settings that start in Urdu and are not saved.
///
/// The database and everything that uses it exist only while the app is
/// unlocked (M3 FE-2): [db], [households], [patients], [visits] and [sync]
/// throw a [StateError] while it is locked. Screens that use them are closed on
/// lock.
class AppServices {
  /// [voice] is the phone's text-to-speech unless a test gives a fake. With
  /// [autoSync] false (tests), records sync only when asked.
  AppServices({
    required this.opener,
    required this.api,
    AppSettings? settings,
    Duration? autoLockAfter,
    int? passwordIterations,
    this.location = const GeolocatorLocationService(),
    Voice? voice,
    bool autoSync = true,
    this.visitRanges,
  }) : settings = settings ?? AppSettings() {
    session = Session(
      opener: opener,
      api: api,
      settings: this.settings,
      autoLockAfter: autoLockAfter ?? const Duration(minutes: 5),
      passwordIterations: passwordIterations ?? PasswordKey.defaultIterations,
    );
    this.autoSync = AutoSync(session: session, enabled: autoSync);
    this.voice = VoiceGuidance(settings: this.settings, voice: voice ?? TtsVoice());
  }

  /// Real services on the phone. [settings] come from [AppSettings.load] and
  /// [visitRanges] from [VisitRanges.load]. A test build uses the server address
  /// saved on the sign-in screen, if any.
  factory AppServices.onDevice({required AppSettings settings, required VisitRanges visitRanges}) => AppServices(
    opener: EncryptedDatabaseOpener(),
    api: SyncApi(baseUrl: (testBuild ? settings.serverAddress : null) ?? apiBaseUrl),
    settings: settings,
    visitRanges: visitRanges,
  );

  final DatabaseOpener opener;
  final SyncApi api;
  final AppSettings settings;

  /// The phone's GPS, for the home location (M2 FE-3).
  final LocationService location;

  /// The visit form's range checks, read from the app's config file at start
  /// (M3 FE-1). The form reads the file itself when this is null.
  final VisitRanges? visitRanges;

  /// Who is signed in, the tokens for sync (M1 FE-2) and the open database.
  late final Session session;

  /// Syncs on its own while the app is unlocked and online (M3 FE-2).
  late final AutoSync autoSync;

  /// Reads field labels aloud in Urdu (M3 FE-3).
  late final VoiceGuidance voice;

  /// The open database and its repositories (M3 FE-2).
  LocalData get data => session.data ?? (throw StateError('The app is locked: sign in to open the database'));

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
  /// sign-in screen of a test build offers this (see `testBuild`).
  Future<void> setServerAddress(String address) async {
    api.baseUrl = address;
    await settings.setServerAddress(address);
  }

  /// Locks the session and closes the database, for example at the end of a test.
  Future<void> dispose() async {
    autoSync.dispose();
    voice.dispose();
    session.lock(null);
    await session.closed;
    await opener.dispose();
  }
}
