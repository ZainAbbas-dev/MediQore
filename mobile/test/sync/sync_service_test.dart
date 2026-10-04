import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mediqore/auth/local_account.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/household_repository.dart';
import 'package:mediqore/data/patient_repository.dart';
import 'package:mediqore/data/visit_repository.dart';
import 'package:mediqore/sync/sync_api.dart';
import 'package:mediqore/sync/sync_service.dart';

import '../support/fake_sync_server.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late HouseholdRepository households;
  late FakeSyncServer server;
  late SyncService sync;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    households = HouseholdRepository(db);
    server = FakeSyncServer()
      ..approve('device-1')
      ..validAccessTokens.add('token-1');
    sync = SyncService(db: db, api: SyncApi(client: server.client, baseUrl: 'http://test/api/v1'), deviceId: 'device-1');
  });

  tearDown(() => db.close());

  test('creating a household writes the record and its outbox entry together', () async {
    final h = await households.create(village: 'Test village', latitude: 33.6844, longitude: 73.0479);

    expect(await households.all(), hasLength(1));
    final queued = await db.select(db.outbox).getSingle();
    expect(queued.recordId, h.id);
    final payload = jsonDecode(queued.payload) as Map<String, dynamic>;
    expect(payload, containsPair('table', 'households'));
    expect(payload['data'], containsPair('village', 'Test village'));
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(h.id), isTrue,
        reason: 'ids are UUID v4 made on the device');
  });

  test('sync pushes the outbox, stores server numbers and empties the queue', () async {
    final h = await households.create(village: 'Test village');

    final report = await sync.syncNow('token-1');

    expect(report.pushed, 1);
    expect(await db.pendingCount(), 0);
    final stored = (await households.all()).single;
    expect(stored.serverSeq, server.records[h.id]!['serverSeq']);
    expect(report.lastServerSeq, stored.serverSeq);
  });

  test('pushes as this phone, which the server must have approved (M1 FE-2)', () async {
    await households.create(village: 'Test village');
    final unapproved = SyncService(db: db, api: SyncApi(client: server.client, baseUrl: 'http://test/api/v1'), deviceId: 'device-2');

    await expectLater(
      unapproved.syncNow('token-1'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'DEVICE_NOT_ALLOWED')),
    );
    expect(await db.pendingCount(), 1, reason: 'nothing is lost');
  });

  test('pushes in batches of at most 100', () async {
    for (var i = 0; i < 150; i++) {
      await households.create(village: 'V$i');
    }

    await sync.syncNow('token-1');

    expect(server.pushedBatches.map((b) => b.length), [100, 50]);
    expect(await db.pendingCount(), 0);
  });

  test('pulls records made on other phones and remembers how far it got', () async {
    server.addFromAnotherDevice('0b7f8e2a-3c4d-4e5f-8a9b-1c2d3e4f5a6b', 'Other village');

    final report = await sync.syncNow('token-1');

    expect(report.pulled, 1);
    expect((await households.all()).single.village, 'Other village');
    expect(await sync.lastServerSeq(), 1);

    final again = await sync.syncNow('token-1');
    expect(again.pulled, 0);
  });

  test('a refused record stays on the phone, marked, and stops blocking the queue', () async {
    final refused = await households.create(village: 'Refused');
    await households.create(village: 'Accepted');
    server.rejectIds.add(refused.id);

    final report = await sync.syncNow('token-1');

    expect(report.rejected, 1);
    expect(report.pushed, 1);
    expect(await db.pendingCount(), 0);
    final entry = await db.select(db.outbox).getSingle();
    expect(entry.recordId, refused.id);
    expect(entry.lastError, 'OUT_OF_AREA');

    await sync.syncNow('token-1');
    expect(server.pushedBatches, hasLength(1), reason: 'refused records are not pushed again');
  });

  test('without a network nothing is lost; the next sync sends it', () async {
    await households.create(village: 'Offline');
    server.offline = true;

    await expectLater(sync.syncNow('token-1'), throwsA(isA<http.ClientException>()));
    expect(await db.pendingCount(), 1);

    server.offline = false;
    await sync.syncNow('token-1');
    expect(await db.pendingCount(), 0);
  });

  test('a rejected token surfaces as ApiException and keeps the outbox', () async {
    await households.create(village: 'X');

    await expectLater(
      sync.syncNow('bad-token'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'UNAUTHORIZED')),
    );
    expect(await db.pendingCount(), 1);
  });

  group('registrations (M2)', () {
    const lhw = SessionUser(
      id: 'user-1', username: 'lhw.demo', role: 'lhw', fullName: 'Demo LHW', lhwCode: 'LHW-DEMO-001', areaId: 'area-1');
    late PatientRepository patients;

    setUp(() => patients = PatientRepository(db));

    test('a whole registration is pushed parents first, and every table stores its server number', () async {
      final woman = await patients.register(
        const RegistrationInput(name: 'Synthetic Woman', age: 26, pregnancyMonth: 3, village: 'Dhok Syedan'),
        by: lhw,
      );

      final report = await sync.syncNow('token-1');

      expect(report.pushed, 4);
      expect(server.pushedBatches.single.map((r) => r['table']), ['households', 'women', 'pregnancies', 'obstetric_history']);
      final file = (await patients.file(woman.id))!;
      expect(file.syncStatus, SyncStatus.synced);
      for (final (table, id, seq) in [
        ('households', file.household!.id, file.household!.serverSeq),
        ('women', file.woman.id, file.woman.serverSeq),
        ('pregnancies', file.pregnancy!.id, file.pregnancy!.serverSeq),
        ('obstetric_history', file.history!.id, file.history!.serverSeq),
      ]) {
        expect(seq, server.records[id]!['serverSeq'], reason: table);
      }
    });

    test("another phone's registration is pulled into the patient list, even with the woman before her household", () async {
      // The household was edited after the woman was registered, so it has the higher number.
      server
        ..addRecord('women', 'w-1', {
          'householdId': 'h-1', 'patientCode': 'LHW-DEMO-001-0007', 'name': 'Pulled Woman', 'age': 30,
          'husbandName': null, 'contactNumber': null,
        })
        ..addRecord('pregnancies', 'p-1', {
          'womanId': 'w-1', 'registeredOn': '2026-09-20', 'pregnancyMonthAtRegistration': 5, 'status': 'active',
          'closedOn': null,
        })
        ..addRecord('obstetric_history', 'o-1', {
          'womanId': 'w-1', 'previousPregnancies': 1, 'previousCSections': 0, 'stillbirths': 0, 'knownConditions': null,
        })
        ..addFromAnotherDevice('h-1', 'Chak Beli');

      final report = await sync.syncNow('token-1');

      expect(report.pulled, 4);
      final [summary] = await patients.list();
      expect(summary.woman.patientCode, 'LHW-DEMO-001-0007');
      expect(summary.woman.areaId, 'area-1');
      expect(summary.village, 'Chak Beli');
      expect(summary.pregnancy?.registeredOn, '2026-09-20');
      expect(summary.syncStatus, SyncStatus.synced);
      expect((await patients.file('w-1'))!.history?.previousPregnancies, 1);
    });

    test('a new area clears the old records but keeps those still waiting (M1 FE-3)', () async {
      final synced = await patients.register(
          const RegistrationInput(name: 'Synced', age: 26, pregnancyMonth: 3, village: 'Old village'), by: lhw);
      await sync.syncNow('token-1');
      final waiting = await patients.register(
          const RegistrationInput(name: 'Waiting', age: 26, pregnancyMonth: 3, village: 'Old village'), by: lhw);

      await db.clearAreaData();

      expect((await patients.list()).map((p) => p.woman.name), ['Waiting']);
      expect(await patients.file(synced.id), isNull);
      expect((await patients.file(waiting.id))!.history, isNotNull);
      expect(await sync.lastServerSeq(), 0);
    });
  });

  group('visits (M3)', () {
    const lhw = SessionUser(
      id: 'user-1', username: 'lhw.demo', role: 'lhw', fullName: 'Demo LHW', lhwCode: 'LHW-DEMO-001', areaId: 'area-1');
    late VisitRepository visits;
    late String pregnancyId;

    setUp(() async {
      visits = VisitRepository(db);
      final woman = await PatientRepository(db).register(
        const RegistrationInput(name: 'Synthetic Woman', age: 26, pregnancyMonth: 5, village: 'Dhok Syedan'),
        by: lhw,
      );
      pregnancyId = (await PatientRepository(db).file(woman.id))!.pregnancy!.id;
    });

    VisitInput input({int systolic = 118}) =>
        VisitInput(pregnancyId: pregnancyId, systolicBpMmhg: systolic, diastolicBpMmhg: 76, temperatureC: 36.8, fever: true);

    test('a visit is pushed after its pregnancy and stores its server number (M3 FE-2)', () async {
      final visit = await visits.record(input(), by: lhw);

      final report = await sync.syncNow('token-1');

      expect(report.pushed, 5);
      expect(server.pushedBatches.single.last, containsPair('table', 'visits'));
      expect(server.pushedBatches.single.last['data'], containsPair('pregnancyId', pregnancyId));
      final [summary] = await visits.forPregnancy(pregnancyId);
      expect(summary.syncStatus, SyncStatus.synced);
      expect(summary.visit.serverSeq, server.records[visit.id]!['serverSeq']);
    });

    test('a visit the server holds for review leaves the outbox, is marked held, and is not resent (M3 FE-2)', () async {
      final visit = await visits.record(input(), by: lhw);
      server.holdIds.add(visit.id);

      final report = await sync.syncNow('token-1');

      expect(report.held, 1);
      expect(report.pushed, 4);
      expect(report.rejected, 0);
      expect(await db.pendingCount(), 0, reason: 'nothing is waiting: the server has it');
      final [summary] = await visits.forPregnancy(pregnancyId);
      expect(summary.syncStatus, SyncStatus.held);
      expect(summary.visit.conflictId, 'conflict-${visit.id}');
      expect(summary.visit.serverSeq, isNull);

      await sync.syncNow('token-1');
      expect(server.pushedBatches, hasLength(1), reason: 'a held visit is not pushed again');
    });

    test("the supervisor's decision arrives by pull: kept, or deleted as a duplicate (M3 FE-2)", () async {
      final kept = await visits.record(input(), by: lhw);
      final duplicate = await visits.record(input(systolic: 120), by: lhw);
      server.holdIds.addAll([kept.id, duplicate.id]);
      await sync.syncNow('token-1');
      final pushed = {for (final r in server.pushedBatches.single) r['id']: r};

      server
        ..resolveHeld(pushed[kept.id]!, keep: true)
        ..resolveHeld(pushed[duplicate.id]!, keep: false);
      final report = await sync.syncNow('token-1');

      expect(report.pulled, 2);
      final [summary] = await visits.forPregnancy(pregnancyId);
      expect(summary.visit.id, kept.id, reason: 'the duplicate is deleted and no longer listed');
      expect(summary.syncStatus, SyncStatus.synced);
      expect(summary.visit.conflictId, isNull);
      expect(summary.visit.serverSeq, server.records[kept.id]!['serverSeq']);
    });

    test("another phone's visit is pulled with its vitals in their stored units", () async {
      server.addRecord('visits', 'v-1', {
        'pregnancyId': pregnancyId, 'visitedAt': '2026-10-02T06:30:00.000Z', 'systolicBpMmhg': 150, 'diastolicBpMmhg': 95,
        'weightKg': 61.5, 'temperatureC': 37, 'pulseBpm': 96, 'bloodSugarMmolL': null, 'fetalMovement': 'reduced',
        'swelling': true, 'bleeding': false, 'fever': false, 'anaemiaSigns': 'present', 'urineSymptoms': false,
      });

      await sync.syncNow('token-1');

      final [summary] = await visits.forPregnancy(pregnancyId);
      final v = summary.visit;
      expect((v.systolicBpMmhg, v.diastolicBpMmhg, v.weightKg, v.temperatureC, v.pulseBpm), (150, 95, 61.5, 37.0, 96));
      expect((v.fetalMovement, v.swelling, v.anaemiaSigns), ('reduced', true, 'present'));
      expect(v.visitedAt.isAtSameMomentAs(DateTime.utc(2026, 10, 2, 6, 30)), isTrue);
      expect(v.areaId, 'area-1');
    });
  });
}
