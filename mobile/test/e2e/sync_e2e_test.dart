// End-to-end check against a real API, using the app's own database, outbox,
// sign-in and sync code (P0-6, M1 FE-2). Skipped unless an API address is given:
//
//   flutter test test/e2e/sync_e2e_test.dart --dart-define=E2E_API_BASE_URL=http://localhost:3000/api/v1
//
// Needs the demo accounts (`npm run seed:demo` in db/). Set E2E_PASSWORD if the
// demo password was changed. Each run adds one synthetic household and three
// approved test phones for lhw.demo.
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mediqore/app_services.dart';
import 'package:mediqore/auth/session.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/household_repository.dart';
import 'package:mediqore/sync/sync_api.dart';
import 'package:mediqore/sync/sync_service.dart';
import 'package:uuid/uuid.dart';

const String apiBaseUrl = String.fromEnvironment('E2E_API_BASE_URL');
const String password = String.fromEnvironment('E2E_PASSWORD', defaultValue: 'demo-password');

/// What the admin does on the portal's Phone approvals page: sign in and issue
/// the one-time code for the waiting phone (decision 0002).
Future<String> issueCodeAsAdmin(String deviceId) async {
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

  final admin = await send('POST', '/auth/login', body: {'username': 'admin.demo', 'password': password});
  final token = admin['accessToken'] as String;
  final pending = (await send('GET', '/devices/pending', token: token))['devices'] as List;
  expect(pending.map((d) => (d as Map)['id']), contains(deviceId));
  return (await send('POST', '/devices/$deviceId/code', token: token))['code'] as String;
}

/// Signs lhw.demo in from a new phone: the first try asks for the code, the
/// code from the admin approves the phone.
Future<String> signInNewPhone(SyncApi api, String deviceId) async {
  final first = await api.login('lhw.demo', password, deviceId: deviceId);
  expect(first.otpRequired, isTrue, reason: 'a new phone needs its one-time code');
  final code = await issueCodeAsAdmin(deviceId);
  final tokens = await api.verifyOtp('lhw.demo', password, deviceId: deviceId, code: code);
  expect(tokens.user.areaName, isNotNull);

  // The phone is approved now: the next sign-in needs no code.
  final again = await api.login('lhw.demo', password, deviceId: deviceId);
  expect(again.otpRequired, isFalse);
  return again.tokens!.accessToken;
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
    "the app's sign-in on a new phone: code, area download, sync, sign-out (M1 FE-2)",
    () async {
      final services = AppServices(db: AppDatabase(NativeDatabase.memory()), api: SyncApi(baseUrl: apiBaseUrl));
      final session = services.session;

      expect(await session.signIn('lhw.demo', password), SignInResult.needsCode);
      final code = await issueCodeAsAdmin(services.settings.deviceId);
      expect(await session.verifyCode(code), SignInResult.signedIn);

      expect(session.user!.lhwCode, isNotNull);
      expect(session.user!.areaName, 'Demo Area 1');
      expect(await services.households.all(), isNotEmpty, reason: 'the area was downloaded at the first sign-in');

      final report = await session.sync();
      expect(report.rejected, 0);

      // Signed out, the same password unlocks the phone again (online here).
      await session.signOut();
      expect(await session.signIn('lhw.demo', password), SignInResult.signedIn);
      await session.signOut();
      await services.db.close();
    },
    skip: apiBaseUrl.isEmpty ? 'Set --dart-define=E2E_API_BASE_URL to run against a real API' : false,
  );
}
