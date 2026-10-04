import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/auth/local_account.dart';
import 'package:mediqore/auth/session.dart';
import 'package:mediqore/sync/sync_api.dart';

import '../helpers.dart';
import '../support/fake_sync_server.dart';

void main() {
  late FakeSyncServer server;
  late AppServices services;

  Session session() => services.session;
  Future<int> localHouseholds() async => (await services.households.all()).length;

  setUp(() {
    server = FakeSyncServer();
    services = testServices(server);
  });
  tearDown(() => services.db.close());

  group('first sign-in on a phone (M1 FE-2)', () {
    test('needs the internet', () async {
      server.offline = true;

      expect(await session().signIn('lhw.demo', 'demo-password'), SignInResult.needsInternet);
      expect(session().isUnlocked, isFalse);
    });

    test('refuses a wrong password', () async {
      expect(await session().signIn('lhw.demo', 'wrong'), SignInResult.wrongPassword);
    });

    test('asks for the one-time code on a new phone, then signs in and downloads the area', () async {
      server.addFromAnotherDevice('3f2b6c1a-5d4e-4f7a-9b8c-0d1e2f3a4b5c', 'Dhok Syedan');

      expect(await session().signIn(' lhw.demo ', 'demo-password'), SignInResult.needsCode);
      expect(server.pendingDevices, [services.settings.deviceId]);
      expect(session().isUnlocked, isFalse);

      server.issueCode(services.settings.deviceId);
      expect(await session().verifyCode('000000'), SignInResult.codeInvalid);
      expect(await session().verifyCode('482913'), SignInResult.signedIn);

      expect(session().isUnlocked, isTrue);
      expect(session().isOnlineSession, isTrue);
      expect(session().user!.areaName, 'Demo Area 1');
      expect(await localHouseholds(), 1, reason: 'the area was downloaded at the first sign-in');
      final account = LocalAccount.read(services.settings.store)!;
      expect(account.user.username, 'lhw.demo');
      expect(services.settings.store.getString('local_account'), isNot(contains('demo-password')));
    });

    test('explains when no code has been issued yet', () async {
      await session().signIn('lhw.demo', 'demo-password');

      expect(await session().verifyCode('123456'), SignInResult.codeNotIssued);
    });
  });

  group('later sign-ins', () {
    setUp(() async {
      await signInApproved(services, server);
      session().lock();
    });

    test('work offline with the right password only', () async {
      server.offline = true;

      expect(await session().signIn('lhw.demo', 'wrong'), SignInResult.wrongPassword);
      expect(await session().signIn('LHW.DEMO', 'demo-password'), SignInResult.signedInOffline);
      expect(session().isUnlocked, isTrue);
      expect(session().isOnlineSession, isFalse);
      expect(session().passwordKey, isNotNull);
    });

    test('offline, another username still needs the internet', () async {
      server.offline = true;

      expect(await session().signIn('lhw.other', 'demo-password'), SignInResult.needsInternet);
    });

    test('online, the server decides: a changed password is refused even if the old one matches the phone', () async {
      server.password = 'new-password';

      expect(await session().signIn('lhw.demo', 'demo-password'), SignInResult.wrongPassword);
      expect(await session().signIn('lhw.demo', 'new-password'), SignInResult.signedIn);
      session().lock();
      server.offline = true;
      expect(await session().signIn('lhw.demo', 'new-password'), SignInResult.signedInOffline);
    });

    test('download the new area after an admin reassigns the LHW (M1 FE-3)', () async {
      expect(await localHouseholds(), 0);
      server
        ..areaId = 'area-2'
        ..areaName = 'Demo Area 2'
        ..addFromAnotherDevice('7c1d2e3f-4a5b-4c6d-8e9f-0a1b2c3d4e5f', 'New area village');

      expect(await session().signIn('lhw.demo', 'demo-password'), SignInResult.signedIn);

      expect(session().user!.areaName, 'Demo Area 2');
      final villages = (await services.households.all()).map((h) => h.village);
      expect(villages, ['New area village']);
    });
  });

  group('sync with the session tokens', () {
    test('refreshes an expired access token once and carries on', () async {
      await signInApproved(services, server);
      await services.households.create(village: 'Test village');
      server.expireAccessTokens();

      final report = await session().sync();

      expect(report.pushed, 1);
      expect(server.requests, contains('POST /auth/refresh'));
    });

    test('asks for an online sign-in after an offline one, or when the refresh token has ended', () async {
      await signInApproved(services, server);
      session().lock();
      server.offline = true;
      await session().signIn('lhw.demo', 'demo-password');

      await expectLater(session().sync(), throwsA(isA<NeedsOnlineSignIn>()));

      session().lock();
      server.offline = false;
      await session().signIn('lhw.demo', 'demo-password');
      server
        ..expireAccessTokens()
        ..validRefreshTokens.clear();
      await expectLater(session().sync(), throwsA(isA<NeedsOnlineSignIn>()));
    });

    test('locks the app when the account has been deactivated, and refuses offline sign-in afterwards', () async {
      await signInApproved(services, server);
      server.deactivated = true;

      await expectLater(session().sync(), throwsA(isA<ApiException>()));

      expect(session().isUnlocked, isFalse);
      expect(session().notice, SessionNotice.deactivated);
      server.offline = true;
      expect(await session().signIn('lhw.demo', 'demo-password'), SignInResult.deactivated);
    });
  });

  group('another LHW on the same phone', () {
    setUp(() async {
      await signInApproved(services, server);
      await services.households.create(village: 'Unsynced');
      session().lock();
      server
        ..username = 'lhw.second'
        ..userId = 'user-2';
    });

    test('is refused while the first LHW has unsynced records', () async {
      expect(await session().signIn('lhw.second', 'demo-password'), SignInResult.otherUserHasUnsyncedData);
      expect(session().isUnlocked, isFalse);
      expect(server.revokedRefreshTokens, hasLength(1), reason: 'the tokens just issued are revoked');
    });

    test('starts with an empty phone once everything is synced', () async {
      await services.db.delete(services.db.outbox).go();

      expect(await session().signIn('lhw.second', 'demo-password'), SignInResult.signedIn);
      expect(await localHouseholds(), 0);
      expect(LocalAccount.read(services.settings.store)!.user.username, 'lhw.second');
    });
  });

  test('sign-out revokes the refresh token and keeps the account for the next sign-in', () async {
    await signInApproved(services, server);

    await session().signOut();

    expect(session().isUnlocked, isFalse);
    expect(session().notice, SessionNotice.signedOut);
    expect(server.revokedRefreshTokens, hasLength(1));
    expect(session().lastUsername, 'lhw.demo');
  });
}
