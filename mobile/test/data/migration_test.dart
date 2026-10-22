import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/auth/local_account.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/household_repository.dart';
import 'package:mediqore/data/patient_repository.dart';
import 'package:mediqore/data/visit_repository.dart';
import 'dart:convert';

import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

// Turns today's tables back into those of database version 4 (before the
// record versions, the estimated delivery date and blood sugar in its recorded unit).
void _toVersion4(Database raw) {
  for (final table in ['households', 'women', 'pregnancies', 'obstetric_history']) {
    raw.execute('ALTER TABLE $table DROP COLUMN version');
    raw.execute('ALTER TABLE $table DROP COLUMN conflict_id');
  }
  for (final column in ['lmp_date', 'reported_edd', 'estimated_delivery_date', 'edd_basis']) {
    raw.execute('ALTER TABLE pregnancies DROP COLUMN $column');
  }
  raw.execute('ALTER TABLE visits RENAME COLUMN blood_sugar_value TO blood_sugar_mmol_l');
  raw.execute('ALTER TABLE visits RENAME COLUMN blood_sugar_unit TO blood_sugar_entered_unit');
  raw.execute('ALTER TABLE visits DROP COLUMN version');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a phone with the version 1 database (P0-6, M1) upgrades to the current version and keeps its records', () async {
    // The tables as version 1 created them, with one household waiting to be pushed.
    final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute('''
        CREATE TABLE "households" ("id" TEXT NOT NULL, "server_seq" INTEGER NULL, "household_number" TEXT NULL,
          "address" TEXT NULL, "village" TEXT NULL, "latitude" REAL NULL, "longitude" REAL NULL,
          "created_on_device" INTEGER NOT NULL, "deleted_at" INTEGER NULL, PRIMARY KEY ("id"));
        CREATE TABLE "outbox" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "entity_table" TEXT NOT NULL,
          "record_id" TEXT NOT NULL, "payload" TEXT NOT NULL, "priority" INTEGER NOT NULL DEFAULT 0,
          "attempts" INTEGER NOT NULL DEFAULT 0, "last_error" TEXT NULL, "queued_at" INTEGER NOT NULL,
          UNIQUE ("entity_table", "record_id"));
        CREATE TABLE "sync_state" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, PRIMARY KEY ("key"));
        INSERT INTO households (id, village, created_on_device) VALUES ('old-household', 'Old village', 1790000000);
        INSERT INTO outbox (entity_table, record_id, payload, queued_at)
          VALUES ('households', 'old-household', '{}', 1790000000);
        INSERT INTO sync_state (key, value) VALUES ('last_server_seq', '12');
        PRAGMA user_version = 1;
      ''');
    }));
    addTearDown(db.close);

      final [household] = await HouseholdRepository(db).all();
      expect(household.village, 'Old village');
      expect(household.areaId, isNull);
      expect(await db.pendingCount(), 1);
      expect(await db.readState('last_server_seq'), '12');
      expect(await PatientRepository(db).list(), isEmpty, reason: 'the Module 2 tables exist');
      expect(await VisitRepository(db).forPregnancy('any'), isEmpty, reason: 'the Module 3 table exists');
      expect(db.schemaVersion, 5);
    },
  );

  test('a phone with the version 2 database (M2) gets the visits table and keeps its registrations', () async {
    final folder = await Directory.systemTemp.createTemp('mediqore-migration');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/v2.sqlite');
    const lhw = SessionUser(id: 'user-1', username: 'lhw.demo', role: 'lhw', fullName: 'Demo LHW', lhwCode: 'LHW-1', areaId: 'area-1');

    // A version 2 database: today's tables without visits, one woman registered
    // and not synced yet.
    final current = AppDatabase(NativeDatabase(file));
    final woman = await PatientRepository(current).register(
      const RegistrationInput(name: 'Synthetic Woman', age: 25, pregnancyMonth: 3, village: 'Test village'),
      by: lhw,
    );
    await current.close();
    final raw = sqlite3.open(file.path);
    _toVersion4(raw);
    raw.execute('DROP TABLE visits; PRAGMA user_version = 2;');
    raw.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final [summary] = await PatientRepository(db).list();
    expect(summary.woman.patientCode, woman.patientCode);
    expect(await db.pendingCount(), 4, reason: 'the registration is still waiting to be pushed');

    final visit = await VisitRepository(db).record(
      VisitInput(pregnancyId: summary.pregnancy!.id, systolicBpMmhg: 120, diastolicBpMmhg: 80),
      by: lhw,
    );
    expect((await VisitRepository(db).forPregnancy(summary.pregnancy!.id)).single.visit.id, visit.id);
  });

  test('a phone with the version 3 database (M3) gets the blood sugar details and the danger-sign checklist, keeping its visits', () async {
    final folder = await Directory.systemTemp.createTemp('mediqore-migration');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/v3.sqlite');
    const lhw = SessionUser(
      id: 'user-1',
      username: 'lhw.demo',
      role: 'lhw',
      fullName: 'Demo LHW',
      lhwCode: 'LHW-1',
      areaId: 'area-1',
    );

    final current = AppDatabase(NativeDatabase(file));
    final woman = await PatientRepository(current).register(
      const RegistrationInput(name: 'Synthetic Woman', age: 25, pregnancyMonth: 3, village: 'Test village'),
      by: lhw,
    );
    final pregnancy = (await PatientRepository(current).file(woman.id))!.pregnancy!;
    final old = await VisitRepository(current)
        .record(VisitInput(pregnancyId: pregnancy.id, systolicBpMmhg: 120, diastolicBpMmhg: 80, pulseBpm: 80), by: lhw);
    await current.close();
    // The version 3 visits table had none of the new columns.
    final raw = sqlite3.open(file.path);
    _toVersion4(raw);
    for (final column in [
      'blood_sugar_entered_unit',
      'blood_sugar_measured_on',
      'blood_sugar_source',
      'convulsions',
      'severe_headache',
      'blurred_vision',
      'severe_abdominal_pain',
      'fast_breathing',
      'fever_with_weakness',
    ]) {
      raw.execute('ALTER TABLE visits DROP COLUMN $column');
    }
    raw.execute('PRAGMA user_version = 3');
    raw.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final [kept] = await VisitRepository(db).forPregnancy(pregnancy.id);
    expect(kept.visit.id, old.id);
    expect(kept.visit.convulsions, isNull, reason: 'not asked before the checklist existed');

    await VisitRepository(db).record(
      VisitInput(
        pregnancyId: pregnancy.id,
        systolicBpMmhg: 118,
        diastolicBpMmhg: 76,
        pulseBpm: 82,
        bloodSugarValue: 5.2,
        bloodSugarUnit: 'mmol_l',
        bloodSugarMeasuredOn: '2026-10-10',
        bloodSugarSource: 'glucometer',
        convulsions: false,
        severeHeadache: true,
      ),
      by: lhw,
    );
    final visits = await VisitRepository(db).forPregnancy(pregnancy.id);
    expect(visits.first.visit.severeHeadache, isTrue);
    expect(visits.first.visit.bloodSugarSource, 'glucometer');
  });

  test('a phone with the version 4 database gets record versions, the delivery date and blood sugar in its own unit', () async {
    final folder = await Directory.systemTemp.createTemp('mediqore-migration');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/v4.sqlite');
    const lhw = SessionUser(id: 'user-1', username: 'lhw.demo', role: 'lhw', fullName: 'Demo LHW', lhwCode: 'LHW-1', areaId: 'area-1');

    final current = AppDatabase(NativeDatabase(file));
    final woman = await PatientRepository(current).register(
      const RegistrationInput(name: 'Synthetic Woman', age: 25, pregnancyMonth: 3, village: 'Test village'),
      by: lhw,
    );
    final pregnancy = (await PatientRepository(current).file(woman.id))!.pregnancy!;
    final visit = await VisitRepository(current).record(
      VisitInput(
        pregnancyId: pregnancy.id,
        pulseBpm: 80,
        bloodSugarValue: 7.8,
        bloodSugarUnit: 'mg_dl',
        bloodSugarMeasuredOn: '2026-10-10',
        bloodSugarSource: 'glucometer',
      ),
      by: lhw,
    );
    await current.close();
    // Version 4 kept 140 mg/dL as 7.8 mmol/L, and its queued visit said so.
    final raw = sqlite3.open(file.path);
    _toVersion4(raw);
    final old = jsonDecode(raw.select("SELECT payload FROM outbox WHERE entity_table = 'visits'").single['payload'] as String)
        as Map<String, dynamic>;
    final data = Map<String, dynamic>.from(old['data'] as Map)
      ..remove('bloodSugarValue')
      ..remove('bloodSugarUnit')
      ..['bloodSugarMmolL'] = 7.8
      ..['bloodSugarEnteredUnit'] = 'mg_dl';
    raw.execute("UPDATE outbox SET payload = ? WHERE entity_table = 'visits'", [jsonEncode({...old, 'data': data})]);
    raw.execute('PRAGMA user_version = 4');
    raw.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final [kept] = await VisitRepository(db).forPregnancy(pregnancy.id);
    expect(kept.visit.id, visit.id);
    expect((kept.visit.bloodSugarValue, kept.visit.bloodSugarUnit), (140.0, 'mg_dl'), reason: 'back in the unit it was recorded in');
    expect(kept.visit.version, isNull, reason: 'not on the server yet');
    final queued = jsonDecode(
      (await db.customSelect("SELECT payload FROM outbox WHERE entity_table = 'visits'").getSingle()).read<String>('payload'),
    ) as Map<String, dynamic>;
    expect(queued['data'], allOf(containsPair('bloodSugarValue', 140.0), containsPair('bloodSugarUnit', 'mg_dl')));
    expect(queued['data'], isNot(contains('bloodSugarMmolL')));
    final file2 = (await PatientRepository(db).file(woman.id))!;
    expect(file2.pregnancy!.estimatedDeliveryDate, isNull, reason: 'estimated from the month until the server sends it');
  });
}
