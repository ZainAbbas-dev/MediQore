import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/database_opener.dart';

/// The phone's database for tests: in memory, but it behaves like the
/// encrypted file. It remembers the key it was made with and refuses another,
/// and it keeps its records when the app locks, until it is destroyed.
class MemoryDatabaseOpener implements DatabaseOpener {
  final AppDatabase db = AppDatabase(NativeDatabase.memory());
  Uint8List? _key;
  int opened = 0;
  int destroyed = 0;

  @override
  Future<AppDatabase> open(Uint8List key) async {
    if (_key != null && !listEquals(_key, key)) throw WrongDatabaseKey();
    _key = key;
    opened++;
    return db;
  }

  @override
  Future<void> close(AppDatabase db) async {} // kept for the next sign-in, like the file

  @override
  Future<void> destroy() async {
    await db.clearAllData();
    _key = null;
    destroyed++;
  }

  @override
  Future<int?> readablePendingCount() async => null;

  @override
  Future<void> dispose() => db.close();
}
