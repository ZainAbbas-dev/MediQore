// M3 FE-2: background sync, so records reach the server "when connectivity is
// restored" even if the app is locked or closed (roadmap: "background sync when
// online"; Tools table: connectivity_plus + workmanager). Android runs it with
// WorkManager (background_tasks.dart): every 15 minutes while there is a network,
// and soon after the network returns when records were left waiting.
//
// It opens the encrypted database with the random key from the Keystore-backed
// store, the same key the PIN unlock uses (the key never depends on the PIN,
// LI-8), refreshes the tokens, pushes the outbox and pulls the area, then closes
// the database again. Nothing is shown on the screen.
//
// It leaves the rest to the app: it does not sync while the app is unlocked
// (SyncGate), and when the server reports a new area, a deactivation or an
// expired sign-in it only pushes, or stops, so the app handles it at its next
// sync.
import 'dart:convert';

import '../auth/local_account.dart';
import '../auth/secure_store.dart';
import '../auth/session.dart' show SecureKeys;
import '../data/app_database.dart';
import '../data/database_opener.dart';
import '../settings/app_settings.dart';
import 'sync_api.dart';
import 'sync_gate.dart';
import 'sync_service.dart';

enum BackgroundSyncResult {
  /// Pushed and pulled (or only pushed, when the area changed).
  done,

  /// Nothing to do here: no activated account, the app is open, another
  /// background sync is running, or the account is deactivated.
  skipped,

  /// The server could not be reached; Android tries again later.
  offline,

  /// The refresh token no longer works; the LHW signs in again in the app.
  needsSignIn,

  /// The server answered with an error; Android tries again later.
  failed,
}

/// Schedules [BackgroundSync] on the phone (background_tasks.dart); does nothing
/// in tests.
abstract interface class BackgroundScheduler {
  /// Sets up the periodic background sync, once when the app starts.
  Future<void> start();

  /// Asks for one background sync as soon as there is a network, for records
  /// left waiting when the app locks or goes to the background.
  Future<void> syncWhenOnline();
}

class NoBackgroundScheduler implements BackgroundScheduler {
  const NoBackgroundScheduler();

  @override
  Future<void> start() async {}

  @override
  Future<void> syncWhenOnline() async {}
}

class BackgroundSync {
  BackgroundSync({
    required this.opener,
    required this.secure,
    required this.settings,
    required this.api,
    required this.gate,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DatabaseOpener opener;
  final SecureStore secure;
  final AppSettings settings;
  final SyncApi api;
  final SyncGate gate;
  final DateTime Function() _clock;

  Future<BackgroundSyncResult> run() async {
    final account = LocalAccount.read(settings.store);
    if (account == null || account.deactivated) return BackgroundSyncResult.skipped;
    if (await gate.appIsOpen()) return BackgroundSyncResult.skipped;
    if (!await gate.startBackground()) return BackgroundSyncResult.skipped;
    AppDatabase? db;
    try {
      final key = await secure.read(SecureKeys.databaseKey);
      final refreshToken = await secure.read(SecureKeys.refreshToken);
      if (key == null || refreshToken == null) return BackgroundSyncResult.skipped;

      final AuthTokens tokens;
      try {
        tokens = await api.refresh(refreshToken);
      } on ApiException catch (error) {
        // 401: the app asks for the password at its next sync. A deactivation
        // (403) also waits for the app, which locks and explains it.
        return error.statusCode == 401 ? BackgroundSyncResult.needsSignIn : BackgroundSyncResult.failed;
      }
      // Saved at once: the old token is used up now.
      await secure.write(SecureKeys.refreshToken, tokens.refreshToken);

      final database = db = await opener.open(base64Decode(key));
      final sync = SyncService(db: database, api: api, deviceId: settings.deviceId, clock: _clock);
      if (tokens.user.areaId == account.dataAreaId) {
        await sync.syncNow(tokens.accessToken);
      } else {
        // A new area (M1 FE-3): send what waits; the app clears the old area
        // and downloads the new one at its next sync.
        await sync.push(tokens.accessToken);
      }
      await settings.setPendingRecords(await database.pendingCount());
      return BackgroundSyncResult.done;
    } on WrongDatabaseKey {
      return BackgroundSyncResult.skipped;
    } on ApiException {
      return BackgroundSyncResult.failed;
    } on Object catch (error) {
      if (isNetworkError(error)) return BackgroundSyncResult.offline;
      rethrow;
    } finally {
      if (db != null) await opener.close(db);
      await gate.endBackground();
    }
  }
}
