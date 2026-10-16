import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/data/patient_repository.dart';
import 'package:mediqore/sync/auto_sync.dart';
import 'package:mediqore/sync/background_sync.dart';
import 'package:mediqore/sync/sync_gate.dart';

import '../helpers.dart';
import '../support/fake_sync_server.dart';

/// Counts the background syncs the app asks Android for.
class FakeScheduler implements BackgroundScheduler {
  int requested = 0;

  @override
  Future<void> start() async {}

  @override
  Future<void> syncWhenOnline() async => requested++;
}

/// M3 FE-2: records sync on their own while the app is unlocked and online.
/// Real timers, with short intervals.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // for the app lifecycle listener

  late FakeSyncServer server;
  late AppServices services;
  late AutoSync auto;

  setUp(() {
    server = FakeSyncServer();
    services = testServices(server);
  });

  tearDown(() async {
    auto.dispose();
    await services.dispose();
  });

  AutoSync start() => auto = AutoSync(
        session: services.session,
        every: const Duration(milliseconds: 300),
        afterSave: const Duration(milliseconds: 20),
      );

  int pushes() => server.requests.where((r) => r == 'POST /sync/push').length;

  Future<void> until(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> register(String name) => services.patients.register(
        RegistrationInput(name: name, age: 25, pregnancyMonth: 4, village: 'Test village'),
        by: services.session.user!,
      );

  test('a saved record is pushed shortly after, without pressing Sync', () async {
    await activateApp(services, server);
    start();
    await until(() => auto.lastOutcome != null); // the first attempt after sign-in
    expect(auto.online, isTrue);

    await register('Synthetic Woman');

    await until(() => server.records.length == 4);
    await until(() => auto.lastOutcome?.report?.pushed == 4);
    expect(await services.db.pendingCount(), 0);
  });

  test('offline, nothing is lost and the next attempt sends it (retry)', () async {
    await activateApp(services, server);
    server.offline = true;
    start();
    await register('Synthetic Woman');
    await until(() => auto.online == false);
    expect(auto.lastOutcome?.problem, SyncProblem.offline);
    expect(await services.db.pendingCount(), 4);

    server.offline = false; // the connection is back

    await until(() => server.records.length == 4);
    await until(() => auto.online == true);
  });

  test('nothing syncs while the app is locked; syncing starts again after the PIN', () async {
    await activateApp(services, server); // downloads the area once
    services.session.lock(null);
    await services.session.closed;
    final before = server.requests.length;
    start();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(server.requests.skip(before), isEmpty);

    await services.session.unlock(testPin);
    expect(services.session.canSync, isTrue);
    await register('After the PIN');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(await services.db.pendingCount(), 0, reason: 'the saved refresh token is used, without the password');
    expect(server.requests, contains('POST /auth/refresh'));
  });

  test('nothing syncs once the sign-in has expired, until she signs in again', () async {
    await activateApp(services, server);
    server
      ..expireAccessTokens()
      ..validRefreshTokens.clear();
    start();
    expect((await auto.run()).problem, SyncProblem.needsSignIn);
    expect(services.session.canSync, isFalse);
    final before = server.requests.length;

    await register('While expired');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(server.requests.skip(before), isEmpty);
  });

  group('with the network, the gate and background sync', () {
    late StreamController<bool> network;
    late MemorySyncGate gate;
    late FakeScheduler scheduler;

    setUp(() {
      network = StreamController<bool>();
      gate = MemorySyncGate();
      scheduler = FakeScheduler();
    });

    tearDown(() => network.close());

    AutoSync startWith({Duration every = const Duration(hours: 1), Duration pullEvery = const Duration(minutes: 10)}) =>
        auto = AutoSync(
          session: services.session,
          every: every,
          afterSave: const Duration(hours: 1),
          pullEvery: pullEvery,
          settings: services.settings,
          gate: gate,
          scheduler: scheduler,
          connectivity: network.stream,
        );

    test('syncs as soon as the network comes back, without waiting for the next check', () async {
      await activateApp(services, server);
      startWith();
      await register('Saved offline');
      network.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final before = pushes();

      network.add(true);

      await until(() => pushes() > before);
      await until(() => auto.lastOutcome?.report != null);
      expect(await services.db.pendingCount(), 0);
    });

    test('marks the app open while unlocked; on lock, hands waiting records to background sync', () async {
      await activateApp(services, server);
      startWith();
      expect(gate.appOpen, isTrue);
      server.offline = true;
      await register('Still waiting');

      services.session.lock(null);
      await services.session.closed;

      await until(() => !gate.appOpen);
      await until(() => scheduler.requested == 1);
    });

    test('waits for a background sync to finish before its own', () async {
      await activateApp(services, server);
      startWith();
      gate.background = true;
      var finished = false;
      final running = auto.run().then((outcome) => finished = true);

      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(finished, isFalse);
      gate.background = false;

      await running;
      expect(finished, isTrue);
    });

    test('with nothing waiting, checks often but syncs only every pullEvery', () async {
      await activateApp(services, server); // syncs once at activation
      await services.session.sync();
      startWith(every: const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final before = server.requests.where((r) => r == 'POST /auth/refresh').length;

      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(server.requests.where((r) => r == 'POST /auth/refresh').length, before);
    });
  });

  test('a sync that starts while another runs joins it', () async {
    await activateApp(services, server);
    await register('Synthetic Woman');
    start();

    final outcomes = await Future.wait([auto.run(), auto.run(), services.session.sync().then(SyncOutcome.done)]);

    expect(outcomes.map((o) => o.report?.pushed), [4, 4, 4]);
    expect(pushes(), 1);
  });
}
