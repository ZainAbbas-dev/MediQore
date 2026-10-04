import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/auth/local_account.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/household_repository.dart';
import 'package:mediqore/data/patient_repository.dart';
import 'package:mediqore/data/visit_repository.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

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
    expect(db.schemaVersion, 3);
  });

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
}
