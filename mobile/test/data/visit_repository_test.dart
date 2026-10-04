import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/auth/local_account.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/patient_repository.dart';
import 'package:mediqore/data/visit_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const lhw = SessionUser(
      id: 'user-1', username: 'lhw.demo', role: 'lhw', fullName: 'Demo LHW', lhwCode: 'LHW-DEMO-001', areaId: 'area-1');
  late AppDatabase db;
  late VisitRepository visits;
  var now = DateTime.utc(2026, 10, 4, 9, 15, 30, 250);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    visits = VisitRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  test('a visit is saved with its outbox entry, in the units and field names the server takes (M3 FE-1)', () async {
    final visit = await visits.record(
      const VisitInput(
        pregnancyId: 'pregnancy-1',
        systolicBpMmhg: 128,
        diastolicBpMmhg: 84,
        weightKg: 62.5,
        temperatureC: 37.2,
        pulseBpm: 88,
        bloodSugarMmolL: 5.4,
        fetalMovement: 'reduced',
        swelling: true,
        anaemiaSigns: 'severe',
      ),
      by: lhw,
    );

    final entry = await db.select(db.outbox).getSingle();
    expect((entry.entityTable, entry.recordId), ('visits', visit.id));
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    expect(payload, containsPair('areaId', 'area-1'));
    expect(payload['data'], {
      'pregnancyId': 'pregnancy-1',
      'visitedAt': '2026-10-04T09:15:30.000Z',
      'systolicBpMmhg': 128,
      'diastolicBpMmhg': 84,
      'weightKg': 62.5,
      'temperatureC': 37.2,
      'pulseBpm': 88,
      'bloodSugarMmolL': 5.4,
      'fetalMovement': 'reduced',
      'swelling': true,
      'bleeding': false,
      'fever': false,
      'anaemiaSigns': 'severe',
      'urineSymptoms': false,
    });
    expect(visit.createdBy, 'user-1');
    expect(visit.visitedAt, DateTime.utc(2026, 10, 4, 9, 15, 30), reason: 'whole seconds, as it reads back');
  });

  test('optional vitals are sent as null and the symptoms default to none', () async {
    await visits.record(const VisitInput(pregnancyId: 'pregnancy-1', systolicBpMmhg: 110, diastolicBpMmhg: 70), by: lhw);

    final data = (jsonDecode((await db.select(db.outbox).getSingle()).payload) as Map<String, dynamic>)['data'] as Map;
    expect(data['bloodSugarMmolL'], isNull);
    expect(data['fetalMovement'], isNull);
    expect(data['anaemiaSigns'], 'none');
  });

  test('lists the latest visit first by server number, never by the phone clock (LI-7), with each sync state', () async {
    // Saved with the phone clock going backwards: the order must not follow it.
    final waiting = await visits.record(const VisitInput(pregnancyId: 'p-1', systolicBpMmhg: 110, diastolicBpMmhg: 70), by: lhw);
    now = now.subtract(const Duration(days: 3));
    final refused = await visits.record(const VisitInput(pregnancyId: 'p-1', systolicBpMmhg: 112, diastolicBpMmhg: 70), by: lhw);
    final held = await visits.record(const VisitInput(pregnancyId: 'p-1', systolicBpMmhg: 114, diastolicBpMmhg: 70), by: lhw);
    await visits.record(const VisitInput(pregnancyId: 'other', systolicBpMmhg: 116, diastolicBpMmhg: 70), by: lhw);

    // A visit from another phone, numbered by the server.
    await db.into(db.visits).insert(LocalVisit(
          id: 'pulled',
          serverSeq: 7,
          createdOnDevice: now.add(const Duration(days: 30)),
          pregnancyId: 'p-1',
          visitedAt: now.add(const Duration(days: 30)),
          swelling: false,
          bleeding: false,
          fever: false,
          anaemiaSigns: 'none',
          urineSymptoms: false,
        ));
    await (db.update(db.outbox)..where((o) => o.recordId.equals(refused.id)))
        .write(const OutboxCompanion(lastError: Value('OUT_OF_AREA')));
    await (db.delete(db.outbox)..where((o) => o.recordId.equals(held.id))).go();
    await (db.update(db.visits)..where((v) => v.id.equals(held.id))).write(const VisitsCompanion(conflictId: Value('c-1')));

    final listed = await visits.forPregnancy('p-1');

    expect(listed.map((s) => s.visit.id), [held.id, refused.id, waiting.id, 'pulled']);
    expect(listed.map((s) => s.syncStatus), [SyncStatus.held, SyncStatus.refused, SyncStatus.waiting, SyncStatus.synced]);
  });
}
