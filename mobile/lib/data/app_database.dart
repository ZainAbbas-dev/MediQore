import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Household with GPS (M2 FE-3): the first table synced end to end (P0-6).
/// Mirrors the server table; `id` is a UUID v4 made on this device and
/// `serverSeq` is filled in once the server has accepted the record.
@DataClassName('LocalHousehold')
class Households extends Table {
  TextColumn get id => text()();
  IntColumn get serverSeq => integer().nullable()();
  TextColumn get householdNumber => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get village => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();

  /// Device clock: shown to the user, never used to order records (LI-7).
  DateTimeColumn get createdOnDevice => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

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

/// Small key/value store for sync bookkeeping: the device ID and the last
/// server sequence number pulled.
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The phone's local database (Drift + SQLite).
///
/// AES-256 encryption with sqflite_sqlcipher (M3 FE-2) and the key derived from
/// the LHW's password (M1 FE-2, LI-8) come in Phase 1; they change only how the
/// database is opened, not the tables.
@DriftDatabase(tables: [Households, Outbox, SyncState])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens the database file on the phone.
  factory AppDatabase.onDevice() => AppDatabase(driftDatabase(name: 'mediqore'));

  @override
  int get schemaVersion => 1;

  Future<String?> readState(String key) async {
    final row = await (select(syncState)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> writeState(String key, String value) =>
      into(syncState).insertOnConflictUpdate(SyncStateCompanion.insert(key: key, value: value));

  /// Number of records still waiting to be pushed (refused ones excluded).
  Future<int> pendingCount() async {
    final count = outbox.id.count();
    final query = selectOnly(outbox)
      ..addColumns([count])
      ..where(outbox.lastError.isNull());
    return (await query.getSingle()).read(count) ?? 0;
  }
}
