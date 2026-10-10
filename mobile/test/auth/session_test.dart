import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/auth/local_account.dart';
import 'package:mediqore/auth/password_key.dart';
import 'package:mediqore/auth/secure_store.dart';
import 'package:mediqore/auth/session.dart';
import 'package:mediqore/data/household_repository.dart';
import 'package:mediqore/data/patient_repository.dart';
import 'package:mediqore/settings/app_settings.dart';
import 'package:mediqore/sync/sync_api.dart';

import '../helpers.dart';
import '../support/fake_sync_server.dart';
import '../support/memory_database_opener.dart';

void main() {
  late FakeSyncServer server;
  late AppServices services;
  late MemorySecureStore secure;
  late DateTime now;

  Session session() => services.session;
  // Through the test database, so it also works while the app is locked.
  Future<int> localHouseholds() async => (await HouseholdRepository(dbOf(services)).all()).length;
  MemoryDatabaseOpener opener() => services.opener as MemoryDatabaseOpener;

  setUp(() {
    server = FakeSyncServer();
    secure = MemorySecureStore();
    now = DateTime.utc(2026, 10, 10, 9);
    services = testServices(server, null, null, null, null, () => now, secure);
  });
  tearDown(() => services.dispose());

  Future<void> lockAndWait() async {
    session().lock();
    await session().closed;
  }

  group('activation, once per phone (M1 FE-2)', () {
    test('starts on the activation screen', () {
      expect(session().stage, SessionStage.activation);
      expect(() => services.db, throwsStateError, reason: 'nothing is readable before activation');
    });

    test('needs the internet', () async {
      server
        ..issueActivationCode()
        ..offline = true;

      expect(await session().activate('lhw.demo', 'demo-password', 'K7QM-4R2X'), SignInResult.needsInternet);
      expect(session().stage, SessionStage.activation);
    });

    test('refuses a wrong password or a wrong code', () async {
      server.issueActivationCode();

      expect(await session().activate('lhw.demo', 'wrong', 'K7QM-4R2X'), SignInResult.wrongPassword);
      expect(await session().activate('lhw.demo', 'demo-password', 'AAAA-BBBB'), SignInResult.codeInvalid);
      expect(session().stage, SessionStage.activation);
    });

    test('asks for a PIN, then saves the keys in the Keystore and downloads the area', () async {
      server.addFromAnotherDevice('3f2b6c1a-5d4e-4f7a-9b8c-0d1e2f3a4b5c', 'Dhok Syedan');
      server.issueActivationCode();

      expect(await session().activate(' lhw.demo ', 'demo-password', 'k7qm 4r2x'), SignInResult.activated);
      expect(session().stage, SessionStage.createPin);
      expect(session().activatingUser!.username, 'lhw.demo');
      expect(secure.values, isEmpty, reason: 'nothing is saved before the PIN');

      await session().completeActivation('246810');

      expect(session().stage, SessionStage.unlocked);
      expect(session().canSync, isTrue);
      expect(session().user!.areaName, 'Demo Area 1');
      expect(await localHouseholds(), 1, reason: 'the area was downloaded at activation');
      expect(secure.values.keys, containsAll([SecureKeys.databaseKey, SecureKeys.activationSecret, SecureKeys.refreshToken, SecureKeys.pin]));
      expect(base64Decode(secure.values[SecureKeys.databaseKey]!), hasLength(32), reason: 'a random 256-bit key');
      expect(secure.values[SecureKeys.pin], isNot(contains('246810')));
      final account = LocalAccount.read(services.settings.store)!;
      expect(account.user.username, 'lhw.demo');
      expect(account.supervisors.single.phone, '0000-1112223');
      final plain = services.settings.store.getString(AppSettings.accountKey)!;
      expect(plain, isNot(contains('demo-password')));
      expect(plain, isNot(contains(secure.values[SecureKeys.refreshToken]!)));
    });

    test('continues the patient numbers after the highest one the server knows (M2 FE-1)', () async {
      server.lastPatientNumber = 41;
      await activateApp(services, server);

      final woman = await services.patients.register(
        const RegistrationInput(name: 'Synthetic Woman', age: 26, pregnancyMonth: 3),
        by: session().user!,
      );

      expect(woman.patientCode, 'LHW-DEMO-001-0042');
    });

    test('cancelled before the PIN, it saves nothing and revokes the tokens', () async {
      server.issueActivationCode();
      await session().activate('lhw.demo', 'demo-password', 'K7QM-4R2X');

      session().cancelActivation();
      await Future<void>.delayed(Duration.zero);

      expect(session().stage, SessionStage.activation);
      expect(secure.values, isEmpty);
      expect(server.revokedRefreshTokens, hasLength(1));
    });

    test('a supervisor or admin account is told to use the portal', () async {
      server
        ..role = 'supervisor'
        ..issueActivationCode();

      expect(await session().activate('lhw.demo', 'demo-password', 'K7QM-4R2X'), SignInResult.notAnLhwAccount);
    });
  });

  group('the PIN (M1 FE-2)', () {
    setUp(() async {
      await activateApp(services, server, pin: '135790');
      await lockAndWait();
    });

    test('opens the app without the internet', () async {
      server.offline = true;

      final outcome = await session().unlock('135790');

      expect(outcome.result, UnlockResult.unlocked);
      expect(session().stage, SessionStage.unlocked);
      expect(services.households, isNotNull);
    });

    test('makes her wait longer after each wrong PIN: 30 s, 1 min, 5 min, then 15 min', () async {
      final waits = <Duration>[];
      for (var i = 0; i < 5; i++) {
        final outcome = await session().unlock('000000');
        expect(outcome.result, UnlockResult.wrongPin);
        waits.add(outcome.wait);
        now = now.add(outcome.wait);
      }

      expect(waits, const [
        Duration(seconds: 30),
        Duration(minutes: 1),
        Duration(minutes: 5),
        Duration(minutes: 15),
        Duration(minutes: 15),
      ]);
    });

    test('refuses even the right PIN while she must wait, then accepts it and forgets the wrong ones', () async {
      await session().unlock('000000');
      now = now.add(const Duration(seconds: 10));

      final early = await session().unlock('135790');
      expect(early.result, UnlockResult.mustWait);
      expect(early.wait, const Duration(seconds: 20));
      expect(await session().pinWait(), const Duration(seconds: 20));

      now = now.add(const Duration(seconds: 20));
      expect((await session().unlock('135790')).result, UnlockResult.unlocked);
      await lockAndWait();
      expect((await session().unlock('000000')).wait, const Duration(seconds: 30), reason: 'counting starts again');
    });

    test('keeps the wait if the phone clock is set back', () async {
      await session().unlock('000000');
      now = now.subtract(const Duration(hours: 1));

      expect(await session().pinWait(), const Duration(seconds: 30));
    });

    test('the wait survives an app restart', () async {
      await session().unlock('000000');
      final restarted = testServices(server, services.settings, null, null, null, () => now, secure);
      addTearDown(restarted.dispose);

      expect(restarted.session.stage, SessionStage.locked);
      expect(await restarted.session.pinWait(), const Duration(seconds: 30));
    });

    test('can be changed in Settings with the current PIN', () async {
      await session().unlock('135790');

      expect(await session().changePin('000000', '112233'), isFalse);
      expect(await session().changePin('135790', '112233'), isTrue);
      await lockAndWait();
      expect((await session().unlock('135790')).result, UnlockResult.wrongPin);
      now = now.add(const Duration(minutes: 1));
      expect((await session().unlock('112233')).result, UnlockResult.unlocked);
    });
  });

  group('PIN reset with the supervisor\'s reply code (M1 FE-2)', () {
    setUp(() async {
      await activateApp(services, server);
      await services.households.create(village: 'Kept after reset');
      await lockAndWait();
      for (var i = 0; i < 3; i++) {
        await session().unlock('000000');
        now = now.add(const Duration(minutes: 5));
      }
    });

    test('works offline, clears the wait and keeps the records', () async {
      server.offline = true;
      final challenge = session().newResetChallenge();
      expect(challenge, matches(RegExp(r'^\d{6}$')));

      expect(await session().checkResetReply(challenge, '12345678'), isFalse);
      expect(await session().resetPin('222222'), isFalse, reason: 'not before a right reply');
      expect(await session().checkResetReply(challenge, server.replyCodeFor(challenge)), isTrue);
      expect(await session().resetPin('222222'), isTrue);

      expect(session().stage, SessionStage.unlocked);
      expect((await services.households.all()).map((h) => h.village), ['Kept after reset']);
      await lockAndWait();
      expect(await session().pinWait(), Duration.zero);
      expect((await session().unlock('222222')).result, UnlockResult.unlocked);
    });

    test('a reply for another code does not work', () async {
      final challenge = session().newResetChallenge();
      final other = challenge == '000000' ? '000001' : '000000';

      expect(await session().checkResetReply(challenge, server.replyCodeFor(other)), isFalse);
    });
  });

  group('sync with the saved tokens', () {
    test('refreshes the tokens at the first sync after the PIN, also updating the supervisors', () async {
      await activateApp(services, server);
      await services.households.create(village: 'Test village');
      await lockAndWait();
      await session().unlock(testPin);
      server.supervisors = [
        {'name': 'New Supervisor', 'phone': '0000-9998887'},
      ];

      final report = await session().sync();

      expect(report.pushed, 1);
      expect(server.requests.where((r) => r == 'POST /auth/refresh'), hasLength(1));
      expect(session().account!.supervisors.single.name, 'New Supervisor');
      expect(secure.values[SecureKeys.refreshToken], isIn(server.validRefreshTokens));
    });

    test('refreshes an expired access token once and carries on', () async {
      await activateApp(services, server);
      await services.households.create(village: 'Test village');
      server.expireAccessTokens();

      final report = await session().sync();

      expect(report.pushed, 1);
      expect(server.requests, contains('POST /auth/refresh'));
    });

    test('after a password reset, asks to sign in again with the new password; the PIN and records stay', () async {
      await activateApp(services, server);
      await services.households.create(village: 'Not synced yet');
      server
        ..password = 'reset-by-admin'
        ..expireAccessTokens()
        ..validRefreshTokens.clear();

      await expectLater(session().sync(), throwsA(isA<NeedsOnlineSignIn>()));
      expect(session().canSync, isFalse);
      expect(session().isUnlocked, isTrue, reason: 'she keeps working offline');

      expect(await session().signInAgain('demo-password'), SignInResult.wrongPassword);
      expect(await session().signInAgain('reset-by-admin'), SignInResult.signedIn);
      expect(session().canSync, isTrue);
      expect((await session().sync()).pushed, 1);
      expect(opener().destroyed, 1, reason: 'only the destroy before activation: no data was lost');
    });

    test('locks the app when the account has been deactivated; the PIN stops working until she signs in again', () async {
      await activateApp(services, server);
      server.deactivated = true;

      await expectLater(session().sync(), throwsA(isA<ApiException>()));

      expect(session().stage, SessionStage.locked);
      expect(session().notice, SessionNotice.deactivated);
      expect((await session().unlock(testPin)).result, UnlockResult.deactivated);
      expect(await session().signInAgain('demo-password'), SignInResult.deactivated);

      server.deactivated = false;
      expect(await session().signInAgain('demo-password'), SignInResult.signedIn);
      expect(session().stage, SessionStage.locked, reason: 'signing in again does not skip the PIN');
      expect((await session().unlock(testPin)).result, UnlockResult.unlocked);
    });

    test('downloads the new area after an admin reassigns the LHW (M1 FE-3)', () async {
      await activateApp(services, server);
      await services.households.create(village: 'Old area, not synced', areaId: 'area-1');
      server
        ..areaId = 'area-2'
        ..areaName = 'Demo Area 2'
        ..addFromAnotherDevice('7c1d2e3f-4a5b-4c6d-8e9f-0a1b2c3d4e5f', 'New area village')
        ..expireAccessTokens();

      await session().sync();

      expect(session().user!.areaName, 'Demo Area 2');
      expect((await services.households.all()).map((h) => h.village), ['New area village']);
      expect(server.records.values.map((r) => r['data']['village']), contains('Old area, not synced'));
      expect(session().account!.dataAreaId, 'area-2');
    });
  });

  group('sign-out', () {
    test('is refused while records are waiting to be sent', () async {
      await activateApp(services, server);
      await services.households.create(village: 'Waiting');

      expect(await session().signOut(), isFalse);
      expect(session().isUnlocked, isTrue);
    });

    test('removes the account, the keys and the records; the phone needs a new activation', () async {
      await activateApp(services, server);
      await services.households.create(village: 'Synced');
      await session().sync();
      final oldDeviceId = services.settings.deviceId;

      expect(await session().signOut(), isTrue);

      expect(session().stage, SessionStage.activation);
      expect(session().notice, SessionNotice.signedOut);
      expect(secure.values, isEmpty);
      expect(LocalAccount.read(services.settings.store), isNull);
      expect(await localHouseholds(), 0);
      expect(server.revokedRefreshTokens, hasLength(1));
      expect(services.settings.deviceId, isNot(oldDeviceId), reason: 'a new installation ID for the next activation');
    });
  });

  group('the encrypted database (M3 FE-2, LI-8)', () {
    test('opens only at unlock, with the Keystore key, and closes when the app locks', () async {
      await activateApp(services, server);
      await services.households.create(village: 'Before lock');
      await lockAndWait();

      expect(() => services.households, throwsStateError);
      await session().unlock(testPin);
      expect((await services.households.all()).map((h) => h.village), ['Before lock']);
      expect(opener().opened, 2);
    });

    test('keeps the number of waiting records outside the database', () async {
      await activateApp(services, server);
      await services.households.create(village: 'Waiting');
      await lockAndWait();
      expect(services.settings.pendingRecords, 1);

      await session().unlock(testPin);
      await session().sync();
      await lockAndWait();
      expect(services.settings.pendingRecords, 0);
    });

    test('a key that does not open the database is refused', () async {
      await activateApp(services, server);
      await lockAndWait();
      await opener().destroy();
      await opener().open(Uint8List.fromList(List.filled(32, 9))); // made with another key

      expect((await session().unlock(testPin)).result, UnlockResult.failed);
      expect(session().isUnlocked, isFalse);
    });
  });

  group('a phone that ran an earlier app version (password key)', () {
    late Uint8List oldKey;

    Future<void> earlierVersion({required String userId, int pending = 0}) async {
      final (key, derived) = await PasswordKey.create('demo-password', iterations: 1000);
      oldKey = derived;
      await services.settings.store.setString(
        AppSettings.legacyAccountKey,
        jsonEncode({
          'user': {'id': userId, 'username': 'old.user', 'role': 'lhw', 'fullName': 'Old User'},
          'key': key.toJson(),
        }),
      );
      await services.settings.setPendingRecords(pending);
      opener().useKey(oldKey);
      await HouseholdRepository(dbOf(services)).create(village: 'From the earlier version');
    }

    test('keeps the records of the same LHW, moved to the new random key', () async {
      await earlierVersion(userId: server.userId, pending: 1);

      await activateApp(services, server);

      expect(session().lostUnsyncedRecords, isFalse);
      expect(server.records.values.map((r) => r['data']['village']), contains('From the earlier version'));
      expect(LegacyAccount.read(services.settings.store), isNull, reason: 'the old account is removed');
      await lockAndWait();
      expect((await session().unlock(testPin)).result, UnlockResult.unlocked);
    });

    test('says so when her password changed since and unsynced records could not be opened', () async {
      await earlierVersion(userId: server.userId, pending: 1);
      server.password = 'changed';

      final code = server.issueActivationCode();
      await session().activate('lhw.demo', 'changed', code);
      await session().completeActivation(testPin);

      expect(session().lostUnsyncedRecords, isTrue);
      expect(await localHouseholds(), 0);
    });

    test('refuses another LHW while the earlier one has unsynced records', () async {
      await earlierVersion(userId: 'someone-else', pending: 2);
      final code = server.issueActivationCode();

      expect(await session().activate('lhw.demo', 'demo-password', code), SignInResult.otherUserHasUnsyncedData);
      await Future<void>.delayed(Duration.zero);
      expect(server.revokedRefreshTokens, hasLength(1));
    });
  });
}
