import 'dart:convert';

import 'package:drift/drift.dart';

part 'app_database.g.dart';

// Every synced table carries the same base columns as on the server (roadmap,
// Data model): `id` is a UUID v4 made on this device, `serverSeq` is filled in
// once the server has accepted the record, `areaId` is the area the record was
// made in (M1 FE-3) and `createdBy` the user who made it. `createdOnDevice` is
// the device clock: shown to the user, never used to order records (LI-7).

/// Household with GPS (M2 FE-3), reused later by the polio and child modules.
/// The registration form's village and address are stored here.
@DataClassName('LocalHousehold')
class Households extends Table {
  TextColumn get id => text()();
  IntColumn get serverSeq => integer().nullable()();
  TextColumn get householdNumber => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get village => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  DateTimeColumn get createdOnDevice => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get areaId => text().nullable()();
  TextColumn get createdBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A registered woman (M2 FE-1). The patient ID is the LHW code plus a counter
/// kept on this phone, so it is unique without a connection.
@DataClassName('LocalWoman')
class Women extends Table {
  TextColumn get id => text()();
  IntColumn get serverSeq => integer().nullable()();
  TextColumn get areaId => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdOnDevice => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// No foreign key: a pulled woman can arrive before her household.
  TextColumn get householdId => text()();
  TextColumn get patientCode => text()();
  TextColumn get name => text()();
  IntColumn get age => integer().nullable()();
  TextColumn get husbandName => text().nullable()();
  TextColumn get contactNumber => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The pregnancy file (M2 FE-1). A woman can have several pregnancies over
/// time, but only one active at a time.
@DataClassName('LocalPregnancy')
class Pregnancies extends Table {
  TextColumn get id => text()();
  IntColumn get serverSeq => integer().nullable()();
  TextColumn get areaId => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdOnDevice => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get womanId => text()();

  /// A calendar date, YYYY-MM-DD, as the server stores it.
  TextColumn get registeredOn => text()();
  IntColumn get pregnancyMonthAtRegistration => integer()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get closedOn => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Obstetric history captured at registration: the baseline risk profile (M2 FE-2).
@DataClassName('LocalObstetricHistory')
class ObstetricHistory extends Table {
  TextColumn get id => text()();
  IntColumn get serverSeq => integer().nullable()();
  TextColumn get areaId => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdOnDevice => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get womanId => text()();
  IntColumn get previousPregnancies => integer().withDefault(const Constant(0))();
  IntColumn get previousCSections => integer().withDefault(const Constant(0))();
  IntColumn get stillbirths => integer().withDefault(const Constant(0))();
  TextColumn get knownConditions => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One home visit with its vitals and symptoms (M3 FE-1). Units are in the
/// names and never converted in storage: BP in mmHg, weight in kg, temperature
/// in °C, pulse in beats per minute, blood sugar in mmol/L.
@DataClassName('LocalVisit')
class Visits extends Table {
  TextColumn get id => text()();
  IntColumn get serverSeq => integer().nullable()();
  TextColumn get areaId => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdOnDevice => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get pregnancyId => text()();

  /// Device clock: shown and counted, never used to order or resolve records (LI-7).
  DateTimeColumn get visitedAt => dateTime()();
  IntColumn get systolicBpMmhg => integer().nullable()();
  IntColumn get diastolicBpMmhg => integer().nullable()();
  RealColumn get weightKg => real().nullable()();
  RealColumn get temperatureC => real().nullable()();
  IntColumn get pulseBpm => integer().nullable()();
  RealColumn get bloodSugarMmolL => real().nullable()();

  /// normal, reduced or absent; null when not assessed.
  TextColumn get fetalMovement => text().nullable()();
  BoolColumn get swelling => boolean().withDefault(const Constant(false))();
  BoolColumn get bleeding => boolean().withDefault(const Constant(false))();
  BoolColumn get fever => boolean().withDefault(const Constant(false))();

  /// none, present or severe.
  TextColumn get anaemiaSigns => text().withDefault(const Constant('none'))();
  BoolColumn get urineSymptoms => boolean().withDefault(const Constant(false))();

  /// Set when the server held this visit for supervisor review, because the
  /// same pregnancy already had a visit that day (M3 FE-2). Cleared when the
  /// supervisor's decision arrives by pull.
  TextColumn get conflictId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Records waiting to be pushed (roadmap, Offline sync). Every local write adds
/// or replaces the record's entry in the same transaction, so only the latest
/// version of each record is queued.
@DataClassName('OutboxEntry')
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Server table name, for example `households`.
  TextColumn get entityTable => text()();
  TextColumn get recordId => text()();

  /// The record as it is pushed (JSON), see `docs/openapi.yaml` SyncPushRequest.
  TextColumn get payload => text()();

  /// Higher goes first; emergency alerts will use this (M5 FE-4).
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Set when the server refused the record; it is then no longer pushed.
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get queuedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {entityTable, recordId},
      ];
}

/// Small key/value store for sync bookkeeping: the last server sequence number
/// pulled and the patient counter.
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The record as `/sync/push` takes it (docs/openapi.yaml, SyncPushRequest).
Map<String, Object?> syncPayload({
  required String table,
  required String id,
  required String? areaId,
  required DateTime createdOnDevice,
  required DateTime? deletedAt,
  required Map<String, Object?> data,
}) =>
    {
      'table': table,
      'id': id,
      'areaId': ?areaId,
      'createdOnDevice': createdOnDevice.toUtc().toIso8601String(),
      'deleted': deletedAt != null,
      'data': data,
    };

/// The phone's local database (Drift + SQLite), encrypted with AES-256 and the
/// key derived from the LHW's password (M3 FE-2, M1 FE-2, LI-8). The encryption
/// lives in how it is opened (database_opener.dart), not in the tables.
@DriftDatabase(tables: [Households, Women, Pregnancies, ObstetricHistory, Visits, Outbox, SyncState])
class AppDatabase extends _$AppDatabase {
  /// On the phone, open it through EncryptedDatabaseOpener (M3 FE-2), never
  /// directly: the file is only readable with the key from the password.
  AppDatabase(super.executor);

  /// 1: households (P0-6). 2: women, pregnancies, obstetric history (M2) and the
  /// area and creator of every record (M1 FE-3). 3: visits (M3).
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(households, households.areaId);
            await m.addColumn(households, households.createdBy);
            await m.createTable(women);
            await m.createTable(pregnancies);
            await m.createTable(obstetricHistory);
          }
          if (from < 3) {
            await m.createTable(visits);
          }
        },
      );

  /// The synced tables by server name, parents before children: the order the
  /// outbox fills when a whole registration is saved at once.
  static const List<String> syncedTables = ['households', 'women', 'pregnancies', 'obstetric_history', 'visits'];

  static const String lastServerSeqKey = 'last_server_seq';
  static const String _patientCounterKey = 'patient_counter';

  Future<String?> readState(String key) async {
    final row = await (select(syncState)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> writeState(String key, String value) =>
      into(syncState).insertOnConflictUpdate(SyncStateCompanion.insert(key: key, value: value));

  /// Queues [payload] for the next push, replacing an earlier version of the
  /// same record that has not been pushed yet. Call it in the same transaction
  /// as the write (roadmap, Offline sync).
  Future<void> enqueue(Map<String, Object?> payload, {required DateTime queuedAt}) {
    final text = jsonEncode(payload);
    return into(outbox).insert(
      OutboxCompanion.insert(
        entityTable: payload['table']! as String,
        recordId: payload['id']! as String,
        payload: text,
        queuedAt: queuedAt.toUtc(),
      ),
      onConflict: DoUpdate(
        (_) => OutboxCompanion(
          payload: Value(text),
          attempts: const Value(0),
          lastError: const Value(null),
          queuedAt: Value(queuedAt.toUtc()),
        ),
        target: [outbox.entityTable, outbox.recordId],
      ),
    );
  }

  /// Stores the number the server gave a pushed record.
  Future<void> setServerSeq(String table, String id, int serverSeq) async {
    final target = _syncedTable(table);
    await customUpdate(
      'UPDATE ${target.actualTableName} SET server_seq = ? WHERE id = ?',
      variables: [Variable.withInt(serverSeq), Variable.withString(id)],
      updates: {target},
    );
  }

  TableInfo<Table, Object?> _syncedTable(String name) {
    if (!syncedTables.contains(name)) throw ArgumentError.value(name, 'table', 'not a synced table');
    return allTables.firstWhere((t) => t.actualTableName == name);
  }

  /// Removes the area's records and the pull cursor, so the next pull fetches
  /// the whole area again. Used when an admin moves the LHW to another area
  /// (M1 FE-3). Records still waiting in the outbox are kept.
  Future<void> clearAreaData() => transaction(() async {
        for (final table in syncedTables) {
          final target = _syncedTable(table);
          await customUpdate(
            'DELETE FROM ${target.actualTableName} '
            'WHERE id NOT IN (SELECT record_id FROM outbox WHERE entity_table = ?)',
            variables: [Variable.withString(table)],
            updates: {target},
            updateKind: UpdateKind.delete,
          );
        }
        await (delete(syncState)..where((s) => s.key.equals(lastServerSeqKey))).go();
      });

  /// Removes every local record, for when another user signs in on this phone.
  /// The caller checks first that nothing is waiting to be pushed.
  Future<void> clearAllData() => transaction(() async {
        await delete(outbox).go();
        for (final table in syncedTables) {
          await delete(_syncedTable(table)).go();
        }
        await delete(syncState).go();
      });

  /// Number of records still waiting to be pushed (refused ones excluded).
  Future<int> pendingCount() async {
    final count = outbox.id.count();
    final query = selectOnly(outbox)
      ..addColumns([count])
      ..where(outbox.lastError.isNull());
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Makes sure the next patient number is above [lastUsed], the highest
  /// number the server knows for this LHW (M2 FE-1).
  Future<void> raisePatientCounter(int lastUsed) => transaction(() async {
        final current = int.tryParse(await readState(_patientCounterKey) ?? '') ?? 0;
        if (lastUsed > current) await writeState(_patientCounterKey, '$lastUsed');
      });

  /// The next patient number for [lhwCode], counted on this phone (M2 FE-1).
  /// It is above the saved counter and above every patient ID with this code
  /// already on the phone. Call it inside the transaction that saves the woman.
  Future<int> takePatientNumber(String lhwCode) async {
    var last = int.tryParse(await readState(_patientCounterKey) ?? '') ?? 0;
    final prefix = '$lhwCode-';
    final codes = await (selectOnly(women)
          ..addColumns([women.patientCode])
          ..where(women.patientCode.like('${_escapeLike(prefix)}%', escapeChar: r'\')))
        .map((row) => row.read(women.patientCode)!)
        .get();
    for (final code in codes) {
      final number = int.tryParse(code.substring(prefix.length));
      if (number != null && number > last) last = number;
    }
    final next = last + 1;
    await writeState(_patientCounterKey, '$next');
    return next;
  }

  static String _escapeLike(String text) => text.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
}
