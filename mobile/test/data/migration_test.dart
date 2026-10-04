import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/household_repository.dart';
import 'package:mediqore/data/patient_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a phone with the version 1 database (P0-6, M1) upgrades to version 2 and keeps its records', () async {
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
    expect(db.schemaVersion, 2);
  });
}
