// Phase 0 end-to-end check (P0-6) against a real API, using the app's own
// database, outbox and sync code. Skipped unless an API address is given:
//
//   flutter test test/e2e/sync_e2e_test.dart --dart-define=E2E_API_BASE_URL=http://localhost:3000/api/v1
//
// Needs the demo accounts (`npm run seed:demo` in db/). Set E2E_PASSWORD if the
// demo password was changed. Each run adds one synthetic household.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/household_repository.dart';
import 'package:mediqore/sync/sync_api.dart';
import 'package:mediqore/sync/sync_service.dart';

const String apiBaseUrl = String.fromEnvironment('E2E_API_BASE_URL');
const String password = String.fromEnvironment('E2E_PASSWORD', defaultValue: 'demo-password');

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'a household created offline on one phone reaches the server and another phone',
    () async {
      final api = SyncApi(baseUrl: apiBaseUrl);
      final token = await api.login('lhw.demo', password);

      // Phone 1: create the record with no connection involved, then sync.
      final phone1 = AppDatabase(NativeDatabase.memory());
      final created = await HouseholdRepository(phone1).create(
        householdNumber: 'E2E-${DateTime.now().millisecondsSinceEpoch}',
        village: 'End-to-end village',
        latitude: 33.6844,
        longitude: 73.0479,
      );
      expect(await phone1.pendingCount(), 1);

      final report = await SyncService(db: phone1, api: api).syncNow(token);
      expect(report.pushed, 1);
      expect(await phone1.pendingCount(), 0);
      final synced = (await HouseholdRepository(phone1).all()).singleWhere((h) => h.id == created.id);
      expect(synced.serverSeq, isNotNull);

      // Phone 2: a fresh install pulls everything in the area, including the new record.
      final phone2 = AppDatabase(NativeDatabase.memory());
      await SyncService(db: phone2, api: api).syncNow(token);
      final pulled = (await HouseholdRepository(phone2).all()).singleWhere((h) => h.id == created.id);
      expect(pulled.householdNumber, created.householdNumber);
      expect(pulled.serverSeq, synced.serverSeq);

      // ignore: avoid_print
      print('E2E OK: ${created.householdNumber} has server number ${synced.serverSeq}');
      await phone1.close();
      await phone2.close();
    },
    skip: apiBaseUrl.isEmpty ? 'Set --dart-define=E2E_API_BASE_URL to run against a real API' : false,
  );
}
