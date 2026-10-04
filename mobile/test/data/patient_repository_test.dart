import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/auth/local_account.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/household_repository.dart';
import 'package:mediqore/data/patient_repository.dart';

const lhw = SessionUser(
  id: 'user-1',
  username: 'lhw.demo',
  role: 'lhw',
  fullName: 'Demo LHW',
  lhwCode: 'LHW-DEMO-001',
  areaId: 'area-1',
  areaName: 'Demo Area 1',
);

RegistrationInput input({
  String name = 'Synthetic Woman',
  String? village = 'Dhok Syedan',
  String? householdId,
  String? husbandName,
  double? latitude = 33.6844,
  double? longitude = 73.0479,
}) =>
    RegistrationInput(
      name: name,
      age: 26,
      husbandName: husbandName,
      contactNumber: '03001234567',
      pregnancyMonth: 3,
      householdId: householdId,
      village: village,
      address: 'House 12',
      latitude: latitude,
      longitude: longitude,
      previousPregnancies: 2,
      previousCSections: 1,
      knownConditions: 'Asthma',
    );

void main() {
  late AppDatabase db;
  late PatientRepository patients;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    patients = PatientRepository(db, clock: () => DateTime(2026, 10, 4, 10, 30));
  });
  tearDown(() => db.close());

  Future<List<Map<String, dynamic>>> queued() async {
    final entries = await (db.select(db.outbox)..orderBy([(o) => OrderingTerm.asc(o.id)])).get();
    return [for (final e in entries) jsonDecode(e.payload) as Map<String, dynamic>];
  }

  group('register (M2 FE-1, FE-2, FE-3)', () {
    test('saves the household, woman, pregnancy file and history with their outbox entries, parents first', () async {
      final woman = await patients.register(input(), by: lhw);

      expect(woman.patientCode, 'LHW-DEMO-001-0001');
      final outbox = await queued();
      expect(outbox.map((p) => p['table']), ['households', 'women', 'pregnancies', 'obstetric_history']);
      expect(outbox.map((p) => p['areaId']).toSet(), {'area-1'}, reason: 'each record carries the area it was made in');
      final [household, womanPayload, pregnancy, history] = outbox;
      expect(household['data'], containsPair('village', 'Dhok Syedan'));
      expect(household['data'], containsPair('latitude', 33.6844));
      expect(womanPayload['data'], {
        'householdId': household['id'],
        'patientCode': 'LHW-DEMO-001-0001',
        'name': 'Synthetic Woman',
        'age': 26,
        'husbandName': null,
        'contactNumber': '03001234567',
      });
      expect(pregnancy['data'], {
        'womanId': woman.id,
        'registeredOn': '2026-10-04',
        'pregnancyMonthAtRegistration': 3,
        'status': 'active',
        'closedOn': null,
      });
      expect(history['data'], {
        'womanId': woman.id,
        'previousPregnancies': 2,
        'previousCSections': 1,
        'stillbirths': 0,
        'knownConditions': 'Asthma',
      });
      expect(await db.pendingCount(), 4);
    });

    test('numbers patients one after another on this phone', () async {
      final first = await patients.register(input(), by: lhw);
      final second = await patients.register(input(name: 'Second'), by: lhw);

      expect([first.patientCode, second.patientCode], ['LHW-DEMO-001-0001', 'LHW-DEMO-001-0002']);
    });

    test('continues after the highest number the server knows, and after any ID already on the phone', () async {
      await db.raisePatientCounter(41);
      expect((await patients.register(input(), by: lhw)).patientCode, 'LHW-DEMO-001-0042');

      // A pulled record from another phone of the same LHW with a higher number.
      await db.into(db.women).insert(WomenCompanion.insert(
            id: 'pulled',
            createdOnDevice: DateTime.utc(2026),
            householdId: 'h',
            patientCode: 'LHW-DEMO-001-0057',
            name: 'Pulled',
          ));
      // Another LHW's code that starts the same way does not count.
      await db.into(db.women).insert(WomenCompanion.insert(
            id: 'other',
            createdOnDevice: DateTime.utc(2026),
            householdId: 'h',
            patientCode: 'LHW-DEMO-0010-0999',
            name: 'Other',
          ));
      expect((await patients.register(input(), by: lhw)).patientCode, 'LHW-DEMO-001-0058');

      // A lower number from the server never lowers the counter.
      await db.raisePatientCounter(3);
      expect((await patients.register(input(), by: lhw)).patientCode, 'LHW-DEMO-001-0059');
    });

    test('puts a second woman in the home of one already registered', () async {
      final first = await patients.register(input(), by: lhw);

      final second = await patients.register(input(name: 'Sister-in-law', householdId: first.householdId, village: null), by: lhw);

      expect(second.householdId, first.householdId);
      expect(await HouseholdRepository(db).all(), hasLength(1));
      expect((await queued()).where((p) => p['table'] == 'households'), hasLength(1));
    });

    test('is only for an LHW, and saves nothing otherwise', () async {
      const supervisor = SessionUser(id: 's', username: 's', role: 'supervisor', fullName: 'S');

      await expectLater(patients.register(input(), by: supervisor), throwsStateError);

      expect(await queued(), isEmpty);
      expect(await db.select(db.women).get(), isEmpty);
    });
  });

  group('list (M2 FE-3: area search, sorted by village)', () {
    setUp(() async {
      await patients.register(input(name: 'Zainab', village: 'Chak Beli', husbandName: 'Imran'), by: lhw);
      await patients.register(input(name: 'Amina', village: 'Dhok Syedan'), by: lhw);
      await patients.register(input(name: 'Bushra', village: 'Chak Beli'), by: lhw);
      await patients.register(input(name: 'Kiran', village: null), by: lhw);
    });

    test('sorts by village, then by name, with no village last', () async {
      final list = await patients.list();

      expect(list.map((p) => '${p.village}/${p.woman.name}'),
          ['Chak Beli/Bushra', 'Chak Beli/Zainab', 'Dhok Syedan/Amina', 'null/Kiran']);
      expect(list.first.pregnancy?.pregnancyMonthAtRegistration, 3);
      expect(list.map((p) => p.syncStatus).toSet(), {SyncStatus.waiting});
    });

    test('finds by part of a name, patient ID, husband or village, ignoring case', () async {
      Future<List<String>> names(String search) async => [for (final p in await patients.list(search: search)) p.woman.name];

      expect(await names('zAIN'), ['Zainab']);
      expect(await names('0002'), ['Amina']);
      expect(await names('imran'), ['Zainab']);
      expect(await names('chak'), ['Bushra', 'Zainab']);
      expect(await names('nobody'), isEmpty);
    });

    test('shows which women the server has, is waiting for, or refused', () async {
      final [bushra, zainab, ..._] = await patients.list();
      await (db.delete(db.outbox)..where((o) => o.recordId.equals(bushra.woman.id))).go();
      await (db.update(db.outbox)..where((o) => o.recordId.equals(zainab.woman.id)))
          .write(const OutboxCompanion(lastError: Value('DUPLICATE_PATIENT_ID')));

      final statuses = {for (final p in await patients.list()) p.woman.name: p.syncStatus};

      expect(statuses['Bushra'], SyncStatus.synced);
      expect(statuses['Zainab'], SyncStatus.refused);
      expect(statuses['Amina'], SyncStatus.waiting);
    });
  });

  test('file() returns the whole pregnancy file', () async {
    final woman = await patients.register(input(), by: lhw);

    final file = (await patients.file(woman.id))!;

    expect(file.woman.patientCode, 'LHW-DEMO-001-0001');
    expect(file.household?.village, 'Dhok Syedan');
    expect(file.pregnancy?.registeredOn, '2026-10-04');
    expect(file.history?.previousCSections, 1);
    expect(await patients.file('missing'), isNull);
  });

  test('recording the home location later queues the household again (M2 FE-3)', () async {
    final woman = await patients.register(input(latitude: null, longitude: null), by: lhw);
    await db.delete(db.outbox).go(); // already synced

    await HouseholdRepository(db).setLocation(woman.householdId, latitude: 33.7, longitude: 73.1);

    final [payload] = await queued();
    expect(payload['table'], 'households');
    expect(payload['areaId'], 'area-1');
    expect(payload['data'], containsPair('latitude', 33.7));
  });
}
