// M3 FE-2: background sync on Android with WorkManager (scope Tools table:
// connectivity_plus + workmanager). The work itself is in background_sync.dart.
// - Every 15 minutes (Android's shortest period) while there is a network.
// - Once as soon as there is a network, when the app locks or goes to the
//   background with records waiting.
// Android runs the work even when the app is closed, and retries it with a
// growing delay when the server could not be reached.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../auth/secure_store.dart';
import '../build_flags.dart';
import '../data/database_opener.dart';
import '../settings/app_settings.dart';
import 'background_sync.dart';
import 'sync_api.dart';
import 'sync_gate.dart';

const String _syncTask = 'mediqore-sync';
const String _periodicName = 'mediqore-periodic-sync';
const String _whenOnlineName = 'mediqore-sync-when-online';

/// Called by Android in the background, also when the app is closed.
@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final settings = await AppSettings.load();
      final result = await BackgroundSync(
        opener: EncryptedDatabaseOpener(),
        secure: KeystoreSecureStore(),
        settings: settings,
        api: SyncApi(baseUrl: apiAddressFor(settings)),
        gate: FileSyncGate(),
      ).run();
      // false: Android tries again later with a growing delay.
      return result != BackgroundSyncResult.offline && result != BackgroundSyncResult.failed;
    } on Object catch (error) {
      debugPrint('Background sync failed: $error');
      return false;
    }
  });
}

class WorkmanagerScheduler implements BackgroundScheduler {
  const WorkmanagerScheduler();

  static final Constraints _online = Constraints(networkType: NetworkType.connected);

  @override
  Future<void> start() async {
    if (!Platform.isAndroid) return;
    await Workmanager().initialize(backgroundTaskDispatcher);
    await Workmanager().registerPeriodicTask(
      _periodicName,
      _syncTask,
      frequency: const Duration(minutes: 15),
      constraints: _online,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
    );
  }

  @override
  Future<void> syncWhenOnline() async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerOneOffTask(
      _whenOnlineName,
      _syncTask,
      constraints: _online,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 1),
    );
  }
}
