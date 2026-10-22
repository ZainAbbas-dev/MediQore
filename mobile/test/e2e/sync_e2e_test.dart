// End-to-end check against a real API, using the app's own database, outbox,
// sign-in and sync code (P0-6, M1 FE-2). Skipped unless an API address is given:
//
//   flutter test test/e2e/sync_e2e_test.dart --dart-define=E2E_API_BASE_URL=http://localhost:3000/api/v1
//
// Needs the demo accounts (`npm run seed:demo` in db/). Set E2E_PASSWORD if the
// demo password was changed. Each run adds synthetic records (households,
// three registrations, three visits, one decided edit conflict) and seven
// activated test phones for lhw.demo.
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mediqore/app_services.dart';
import 'package:mediqore/auth/secure_store.dart';
import 'package:mediqore/auth/session.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/household_repository.dart';
import 'package:mediqore/data/patient_repository.dart';
import 'package:mediqore/data/visit_repository.dart';
import 'package:mediqore/sync/background_sync.dart';
import 'package:mediqore/sync/sync_api.dart';
import 'package:mediqore/sync/sync_service.dart';
import 'package:mediqore/sync/sync_gate.dart';
import 'package:uuid/uuid.dart';

import '../support/memory_database_opener.dart';

const String apiBaseUrl = String.fromEnvironment('E2E_API_BASE_URL');
const String password = String.fromEnvironment('E2E_PASSWORD', defaultValue: 'demo-password');

Future<Map<String, dynamic>> send(String method, String path, {String? token, Object? body}) async {
  final request = http.Request(method, Uri.parse('$apiBaseUrl$path'))
    ..headers['Content-Type'] = 'application/json'
    ..headers['Accept'] = 'application/json';
  if (token != null) request.headers['Authorization'] = 'Bearer $token';
  if (body != null) request.body = jsonEncode(body);
  final response = await http.Response.fromStream(await request.send());
  expect(response.statusCode, inInclusiveRange(200, 299), reason: '$method $path: ${response.body}');
  return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
}

/// The admin signed in on the portal (no phone needed).
Future<String> adminToken() async =>
    (await send('POST', '/auth/login', body: {'username': 'admin.demo', 'password': password}))['accessToken'] as String;

/// lhw.demo's account ID, as the admin sees it on the portal.
Future<String> demoLhwId() async {
  final lhws = (await send('GET', '/admin/lhws?search=LHW-DEMO-001', token: await adminToken()))['lhws'] as List;
  return (lhws.single as Map)['id'] as String;
}

/// What the admin does on the portal's LHW accounts page: New activation code
/// for lhw.demo (M1 FE-2).
Future<String> issueCodeAsAdmin() async => (await send(
  'POST',
  '/admin/lhws/${await demoLhwId()}/activation-code',
  token: await adminToken(),
))['activationCode'] as String;

/// Activates a new phone for lhw.demo with a code from the admin; the next
/// sign-in on the same phone needs only the password.
Future<String> signInNewPhone(SyncApi api, String deviceId) async {
  final tokens = await api.activate('lhw.demo', password, code: await issueCodeAsAdmin(), deviceId: deviceId);
  expect(tokens.user.areaName, isNotNull);
  expect(tokens.activationSecret, isNotNull);

  final again = await api.login('lhw.demo', password, deviceId: deviceId);
  return again.accessToken;
}

const String e2ePin = '135790';

AppServices newPhone() => AppServices(
  opener: MemoryDatabaseOpener(),
  api: SyncApi(baseUrl: apiBaseUrl),
  secureStore: MemorySecureStore(),
  pinIterations: 1000,
  autoSync: false,
);

/// The app on a new phone, activated as lhw.demo with the code from the admin.
Future<AppServices> signedInNewPhone() async {
  final services = newPhone();
  expect(await services.session.activate('lhw.demo', password, await issueCodeAsAdmin()), SignInResult.activated);
  await services.session.completeActivation(e2ePin);
  expect(services.session.isUnlocked, isTrue);
  return services;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'a household created offline on one phone reaches the server and another phone',
    () async {
      final api = SyncApi(baseUrl: apiBaseUrl);
      final phone1Id = const Uuid().v4();
      final phone2Id = const Uuid().v4();

      // Phone 1: create the record with no connection involved, then sync.
      final phone1 = AppDatabase(NativeDatabase.memory());
      final created = await HouseholdRepository(phone1).create(
        householdNumber: 'E2E-${DateTime.now().millisecondsSinceEpoch}',
        village: 'End-to-end village',
        latitude: 33.6844,
        longitude: 73.0479,
      );
      expect(await phone1.pendingCount(), 1);

      final token1 = await signInNewPhone(api, phone1Id);
      final report = await SyncService(db: phone1, api: api, deviceId: phone1Id).syncNow(token1);
      expect(report.pushed, 1);
      expect(await phone1.pendingCount(), 0);
      final synced = (await HouseholdRepository(phone1).all()).singleWhere((h) => h.id == created.id);
      expect(synced.serverSeq, isNotNull);

      // Phone 2: a fresh install pulls everything in the area, including the new record.
      final phone2 = AppDatabase(NativeDatabase.memory());
      final token2 = await signInNewPhone(api, phone2Id);
      await SyncService(db: phone2, api: api, deviceId: phone2Id).syncNow(token2);
      final pulled = (await HouseholdRepository(phone2).all()).singleWhere((h) => h.id == created.id);
      expect(pulled.householdNumber, created.householdNumber);
      expect(pulled.serverSeq, synced.serverSeq);

      // A token only works from the phone it was issued to: phone 1's token
      // cannot push in phone 2's name. The server refuses before saving anything.
      final resend = {
        'table': 'households',
        'id': created.id,
        'createdOnDevice': created.createdOnDevice.toUtc().toIso8601String(),
        'data': {
          'householdNumber': created.householdNumber,
          'address': null,
          'village': created.village,
          'latitude': created.latitude,
          'longitude': created.longitude,
        },
      };
      await expectLater(
        api.push(token1, phone2Id, [resend]),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'DEVICE_NOT_ALLOWED')),
      );

      // ignore: avoid_print
      print('E2E OK: ${created.householdNumber} has server number ${synced.serverSeq}');
      await phone1.close();
      await phone2.close();
    },
    skip: apiBaseUrl.isEmpty ? 'Set --dart-define=E2E_API_BASE_URL to run against a real API' : false,
  );

  test(
    "the app's activation on a new phone: code, PIN, area download, sync, PIN reset with the supervisor's reply code, sign-out (M1 FE-2)",
    () async {
      final services = newPhone();
      final session = services.session;

      expect(await session.activate('lhw.demo', password, 'AAAA-BBBB'), SignInResult.codeInvalid);
      expect(await session.activate('lhw.demo', password, await issueCodeAsAdmin()), SignInResult.activated);
      await session.completeActivation(e2ePin);

      expect(session.user!.lhwCode, isNotNull);
      expect(session.user!.areaName, 'Demo Area 1');
      expect(session.account!.supervisors.map((s) => s.name), isNotEmpty, reason: 'the emergency call has a number');
      expect(await services.households.all(), isNotEmpty, reason: 'the area was downloaded at activation');
      expect((await session.sync()).rejected, 0);

      // Locked, the PIN opens the app and the saved refresh token syncs.
      session.lock(null);
      await session.closed;
      expect((await session.unlock(e2ePin)).result, UnlockResult.unlocked);
      expect((await session.sync()).rejected, 0);

      // PIN reset: the supervisor's reply code from the real server is accepted.
      session.lock(null);
      await session.closed;
      final challenge = session.newResetChallenge();
      final supervisor = (await send(
        'POST',
        '/auth/login',
        body: {'username': 'supervisor.demo', 'password': password},
      ))['accessToken'] as String;
      final reply = (await send(
        'POST',
        '/pin-reset/reply-code',
        token: supervisor,
        body: {'lhwId': await demoLhwId(), 'challenge': challenge},
      ))['replyCode'] as String;
      expect(await session.checkResetReply(challenge, reply), isTrue);
      expect(await session.resetPin('246802'), isTrue);
      expect(session.isUnlocked, isTrue);

      expect(await session.signOut(), isTrue);
      expect(session.stage, SessionStage.activation);
      await services.dispose();
    },
    skip: apiBaseUrl.isEmpty ? 'Set --dart-define=E2E_API_BASE_URL to run against a real API' : false,
  );

  test(
    'a woman registered offline on one phone reaches the portal and the next phone, whose patient IDs carry its own activation number (M2)',
    () async {
      final phone1 = await signedInNewPhone();
      final woman = await phone1.patients.register(
        const RegistrationInput(
          name: 'E2E Synthetic Woman',
          age: 27,
          husbandName: 'E2E Synthetic Husband',
          contactNumber: '03001234567',
          pregnancyMonth: 4,
          village: 'End-to-end village',
          address: 'House 1',
          latitude: 33.6844,
          longitude: 73.0479,
          previousPregnancies: 1,
          knownConditions: 'None (synthetic)',
        ),
        by: phone1.session.user!,
      );
      final report = await phone1.session.sync();
      expect(report.rejected, 0, reason: 'the real server accepts what the app sends');
      expect(report.pushed, 4);

      // The supervisor portal lists her with her history (M10 FE-1).
      final listed = await send('GET', '/women?search=${woman.patientCode}', token: await adminToken());
      final [row] = listed['women'] as List;
      expect(row, containsPair('name', 'E2E Synthetic Woman'));
      expect((row as Map)['obstetricHistory'], containsPair('previousPregnancies', 1));
      expect(row['household'], containsPair('village', 'End-to-end village'));

      // A new phone downloads her at sign-in, and its numbers continue after hers.
      final phone2 = await signedInNewPhone();
      final pulled = await phone2.patients.file(woman.id);
      expect(pulled?.woman.patientCode, woman.patientCode);
      expect(pulled?.pregnancy?.pregnancyMonthAtRegistration, 4);
      final next = await phone2.patients.register(
        const RegistrationInput(name: 'E2E Second Woman', age: 25, pregnancyMonth: 2, village: 'End-to-end village'),
        by: phone2.session.user!,
      );
      // Each phone's IDs carry its own activation number, so the two never clash before a sync (M2 FE-1).
      String activation(String code) => code.split('-').reversed.elementAt(1);
      expect(next.patientCode, startsWith(phone2.session.user!.patientCodePrefix!));
      expect(activation(next.patientCode), isNot(activation(woman.patientCode)));
      expect(next.patientCode, isNot(woman.patientCode));
      expect((await phone2.session.sync()).rejected, 0);

      // ignore: avoid_print
      print('E2E M2 OK: ${woman.patientCode} then ${next.patientCode}');
      for (final phone in [phone1, phone2]) {
        await phone.session.signOut();
        await phone.dispose();
      }
    },
    skip: apiBaseUrl.isEmpty ? 'Set --dart-define=E2E_API_BASE_URL to run against a real API' : false,
  );

  test(
    'visits from two phones on the same day are both stored; an edit made on an older version waits for the supervisor, whose decision reaches the phone (M3)',
    () async {
      final phone1 = await signedInNewPhone();
      final woman = await phone1.patients.register(
        const RegistrationInput(name: 'E2E Visit Woman', age: 24, pregnancyMonth: 6, village: 'End-to-end village'),
        by: phone1.session.user!,
      );
      final file = (await phone1.patients.file(woman.id))!;
      final pregnancyId = file.pregnancy!.id;
      final householdId = file.household!.id;
      await phone1.visits.record(
        VisitInput(
          pregnancyId: pregnancyId,
          systolicBpMmhg: 118,
          diastolicBpMmhg: 76,
          weightKg: 58.5,
          temperatureC: 36.8,
          pulseBpm: 82,
          bloodSugarValue: 90,
          bloodSugarUnit: 'mg_dl',
          bloodSugarMeasuredOn: '2026-10-01',
          bloodSugarSource: 'glucometer',
          convulsions: false,
          severeHeadache: false,
          blurredVision: false,
          severeAbdominalPain: false,
          fastBreathing: false,
          feverWithWeakness: false,
        ),
        by: phone1.session.user!,
      );
      final first = await phone1.session.sync();
      expect((first.pushed, first.rejected, first.held), (5, 0, 0), reason: 'the real server takes the visit as the app sends it');

      // Another phone downloads her file and records a second visit the same day: both are stored.
      final phone2 = await signedInNewPhone();
      expect((await phone2.visits.forPregnancy(pregnancyId)).single.syncStatus, SyncStatus.synced);
      final second = await phone2.visits.record(
        VisitInput(pregnancyId: pregnancyId, systolicBpMmhg: 150, diastolicBpMmhg: 96, weightKg: 58.5, temperatureC: 37.9, pulseBpm: 104, bleeding: true),
        by: phone2.session.user!,
      );
      final report = await phone2.session.sync();
      expect((report.held, report.rejected), (0, 0));
      final visits = await phone2.visits.forPregnancy(pregnancyId);
      expect(visits.map((v) => v.syncStatus), [SyncStatus.synced, SyncStatus.synced]);
      expect(visits.first.visit.id, second.id, reason: 'numbered by the server after the first visit');

      // Both phones record the home's GPS; the second edit was made on the older version.
      await phone1.households.setLocation(householdId, latitude: 33.61, longitude: 73.01);
      expect((await phone1.session.sync()).held, 0);
      await phone2.households.setLocation(householdId, latitude: 33.62, longitude: 73.02);
      expect((await phone2.session.sync()).held, 1);

      // The supervisor portal's Conflict Review has both versions; the admin uses the phone's edit.
      final token = await adminToken();
      final pending = ((await send('GET', '/conflicts?status=pending', token: token))['conflicts'] as List).cast<Map>();
      final conflict = pending.singleWhere((c) => (c['incoming'] as Map)['id'] == householdId);
      expect(conflict['reason'], 'outdated_edit');
      expect(conflict['resolutions'], ['keep_server', 'use_device']);
      expect((conflict['incoming'] as Map)['data'], containsPair('latitude', 33.62));
      expect((conflict['existing'] as Map)['data'], containsPair('latitude', 33.61));
      await send('POST', '/conflicts/${conflict['id']}/resolve', token: token, body: {'resolution': 'use_device'});

      // The decision reaches both phones at their next sync.
      for (final phone in [phone2, phone1]) {
        await phone.session.sync();
        final home = (await phone.households.all()).singleWhere((h) => h.id == householdId);
        expect((home.latitude, home.conflictId), (33.62, null));
      }

      final summary = await send('GET', '/dashboard/summary', token: token);
      expect(summary['visitsThisWeek'], greaterThanOrEqualTo(2));

      // ignore: avoid_print
      print('E2E M3 OK: ${woman.patientCode}, conflict ${conflict['id']} used the phone\'s edit');
      for (final phone in [phone1, phone2]) {
        await phone.session.signOut();
        await phone.dispose();
      }
    },
    skip: apiBaseUrl.isEmpty ? 'Set --dart-define=E2E_API_BASE_URL to run against a real API' : false,
  );

  test(
    'background sync sends a record saved before the app locked, and the app syncs on afterwards (M3 FE-2)',
    () async {
      final phone = await signedInNewPhone();
      final woman = await phone.patients.register(
        const RegistrationInput(name: 'E2E Background Woman', age: 27, pregnancyMonth: 5, village: 'End-to-end village'),
        by: phone.session.user!,
      );
      phone.session.lock(null);
      await phone.session.closed;

      final result = await BackgroundSync(
        opener: phone.opener,
        secure: phone.secureStore,
        settings: phone.settings,
        api: phone.api,
        gate: MemorySyncGate(),
      ).run();

      expect(result, BackgroundSyncResult.done);
      expect(phone.settings.pendingRecords, 0);
      final token = await adminToken();
      final women = ((await send('GET', '/women?search=${woman.patientCode}', token: token))['women'] as List).cast<Map>();
      expect(women.single['patientCode'], woman.patientCode);

      // The refresh token background sync saved still works for the app.
      expect((await phone.session.unlock(e2ePin)).result, UnlockResult.unlocked);
      final report = await phone.session.sync();
      expect(report.pushed, 0);

      // ignore: avoid_print
      print('E2E background sync OK: ${woman.patientCode}');
      await phone.session.signOut();
      await phone.dispose();
    },
    skip: apiBaseUrl.isEmpty ? 'Set --dart-define=E2E_API_BASE_URL to run against a real API' : false,
  );
}
