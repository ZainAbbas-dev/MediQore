import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/auth/session.dart';
import 'package:mediqore/sync/background_sync.dart';
import 'package:mediqore/sync/sync_gate.dart';

import '../helpers.dart';
import '../support/fake_sync_server.dart';

/// M3 FE-2: background sync sends waiting records while the app is locked or
/// closed, with the Keystore key and the saved refresh token, and leaves the rest
/// to the app.
void main() {
  late FakeSyncServer server;
  late AppServices services;
  late MemorySyncGate gate;

  setUp(() {
    server = FakeSyncServer();
    services = testServices(server);
    gate = MemorySyncGate();
  });

  tearDown(() => services.dispose());

  BackgroundSync background() => BackgroundSync(
    opener: services.opener,
    secure: services.secureStore,
    settings: services.settings,
    api: services.api,
    gate: gate,
  );

  // Activates the phone, saves a household offline and locks the app.
  Future<void> waitingWhileLocked() async {
    await activateApp(services, server);
    await services.households.create(village: 'Saved offline');
    services.session.lock(null);
    await services.session.closed;
  }

  int pushes() => server.requests.where((r) => r == 'POST /sync/push').length;

  test('sends the waiting records while the app is locked, and keeps the new refresh token', () async {
    await waitingWhileLocked();
    expect(services.settings.pendingRecords, 1);

    final result = await background().run();

    expect(result, BackgroundSyncResult.done);
    expect(server.records.values.where((r) => r['data']?['village'] == 'Saved offline'), hasLength(1));
    expect(services.settings.pendingRecords, 0);
    expect(await dbOf(services).lastSyncAt(), isNotNull);
    expect(await services.secureStore.read(SecureKeys.refreshToken), isIn(server.validRefreshTokens));
    expect(gate.background, isFalse, reason: 'the mark is cleared');

    // The app syncs on with the token background sync saved.
    await services.session.unlock(testPin);
    final report = await services.session.sync();
    expect(report.pushed, 0);
  });

  test('leaves the work to the app while it is unlocked, or to a background sync already running', () async {
    await waitingWhileLocked();

    gate.appOpen = true;
    expect(await background().run(), BackgroundSyncResult.skipped);
    gate.appOpen = false;
    gate.background = true;
    expect(await background().run(), BackgroundSyncResult.skipped);

    expect(pushes(), 0);
  });

  test('without a network nothing is lost; Android tries again later', () async {
    await waitingWhileLocked();
    server.offline = true;

    expect(await background().run(), BackgroundSyncResult.offline);

    server.offline = false;
    expect(await dbOf(services).pendingCount(), 1);
    expect(gate.background, isFalse);
    expect(await background().run(), BackgroundSyncResult.done);
    expect(await dbOf(services).pendingCount(), 0);
  });

  test('stops when the sign-in has expired: the app asks for the password', () async {
    await waitingWhileLocked();
    server.validRefreshTokens.clear(); // a password reset on the portal

    expect(await background().run(), BackgroundSyncResult.needsSignIn);

    expect(pushes(), 0);
    expect(await dbOf(services).pendingCount(), 1);
  });

  test('after an area change it only sends; the app moves the phone to the new area', () async {
    await waitingWhileLocked();
    server.areaId = 'area-2';
    final pulls = server.requests.where((r) => r.startsWith('GET /sync/pull')).length;

    expect(await background().run(), BackgroundSyncResult.done);

    expect(pushes(), 1);
    expect(server.requests.where((r) => r.startsWith('GET /sync/pull')).length, pulls);
  });

  test('does nothing on a phone that is not activated', () async {
    expect(await background().run(), BackgroundSyncResult.skipped);
    expect(server.requests, isEmpty);
  });
}
