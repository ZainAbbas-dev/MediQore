// M3 FE-2, LI-8: the local database is encrypted with AES-256 (the SQLCipher
// format, through the SQLite3 Multiple Ciphers build bundled by package:sqlite3,
// see pubspec.yaml and decision 0006). Its key is 256 random bits made on the
// phone and kept wrapped by the Android Keystore (M1 FE-2, LI-8); it is never
// derived from the password or the PIN, so a password reset or a new PIN keeps
// the records. The database is opened when the PIN unlocks the app and closed
// when it locks.
import 'dart:io';
import 'dart:typed_data';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'app_database.dart';

/// The key does not open the database: it was made with another key.
class WrongDatabaseKey implements Exception {
  @override
  String toString() => 'WrongDatabaseKey';
}

abstract interface class DatabaseOpener {
  /// Opens the phone's database with [key], creating it if there is none.
  /// Throws [WrongDatabaseKey] if the database was made with another key.
  Future<AppDatabase> open(Uint8List key);

  /// Closes [db], for example when the app locks.
  Future<void> close(AppDatabase db);

  /// Encrypts the database with [newKey] instead of [oldKey]: an earlier
  /// version's database, made with the password key, moves to the random key
  /// at activation. Throws [WrongDatabaseKey] if [oldKey] does not open it.
  Future<void> rekey(Uint8List oldKey, Uint8List newKey);

  /// Deletes the database: at activation (unless an earlier version's database
  /// can be kept) and at sign-out.
  Future<void> destroy();

  /// Records still waiting to be pushed, if they can be counted without a key
  /// (only an older, unencrypted database). Null otherwise.
  Future<int?> readablePendingCount();

  /// Releases anything the opener holds, at the end of the app or a test.
  Future<void> dispose();
}

/// Sets the cipher and key on a new connection, then checks that the key is
/// right: SQLCipher reports a wrong key only at the first read.
void unlockDatabase(CommonDatabase raw, String hexKey) {
  _setCipher(raw);
  raw.execute('PRAGMA key = "x\'$hexKey\'"');
  try {
    raw.select('SELECT count(*) FROM sqlite_master');
  } on Object {
    throw WrongDatabaseKey();
  }
}

// AES-256 in the SQLCipher 4 format. The key is already 256 random bits, so it
// is passed raw, without a key derivation.
void _setCipher(CommonDatabase raw) {
  raw.execute("PRAGMA cipher = 'sqlcipher'");
  raw.execute('PRAGMA legacy = 4');
}

String hexOf(Uint8List key) => key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// The database file on the phone, in the app's private documents folder.
class EncryptedDatabaseOpener implements DatabaseOpener {
  /// [directory] and [tempDirectory] default to the app's folders on the phone;
  /// tests pass their own.
  EncryptedDatabaseOpener({Future<Directory> Function()? directory, this._tempDirectory})
      : _directory = directory ?? getApplicationDocumentsDirectory;

  static const String fileName = 'mediqore.sqlite';

  final Future<Directory> Function() _directory;
  final Future<String?> Function()? _tempDirectory;

  Future<File> _file() async => File('${(await _directory()).path}/$fileName');

  @override
  Future<AppDatabase> open(Uint8List key) async {
    final file = await _file();
    final hex = hexOf(key);
    if (await file.exists()) _encryptIfPlain(file.path, hex);
    final db = AppDatabase(driftDatabase(
      name: 'mediqore',
      native: DriftNativeOptions(
        databasePath: () async => file.path,
        tempDirectoryPath: _tempDirectory,
        setup: (raw) => unlockDatabase(raw, hex),
      ),
    ));
    try {
      await db.customSelect('SELECT count(*) FROM sqlite_master').get();
    } on Object catch (error) {
      await db.close();
      if (error is WrongDatabaseKey || '$error'.contains('WrongDatabaseKey') || '$error'.contains('not a database')) {
        throw WrongDatabaseKey();
      }
      rethrow;
    }
    return db;
  }

  @override
  Future<void> close(AppDatabase db) => db.close();

  @override
  Future<void> rekey(Uint8List oldKey, Uint8List newKey) async {
    final file = await _file();
    if (!await file.exists()) throw WrongDatabaseKey();
    _encryptIfPlain(file.path, hexOf(oldKey));
    final raw = sqlite3.open(file.path);
    try {
      unlockDatabase(raw, hexOf(oldKey));
      raw.execute('PRAGMA journal_mode = DELETE');
      raw.execute('PRAGMA rekey = "x\'${hexOf(newKey)}\'"');
    } finally {
      raw.close();
    }
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> destroy() async {
    final file = await _file();
    for (final suffix in ['', '-journal', '-wal', '-shm']) {
      final part = File('${file.path}$suffix');
      if (await part.exists()) await part.delete();
    }
  }

  @override
  Future<int?> readablePendingCount() async {
    final file = await _file();
    if (!await file.exists()) return 0;
    final raw = sqlite3.open(file.path);
    try {
      return raw.select('SELECT count(*) AS n FROM outbox WHERE last_error IS NULL').first['n'] as int;
    } on Object {
      return null; // encrypted, or no outbox yet
    } finally {
      raw.close();
    }
  }

  // Phones that ran an earlier version have an unencrypted database. It is
  // encrypted in place with the key, so records not yet synced are kept.
  static void _encryptIfPlain(String path, String hexKey) {
    final raw = sqlite3.open(path);
    try {
      try {
        raw.select('SELECT count(*) FROM sqlite_master');
      } on Object {
        return; // already encrypted
      }
      raw.execute('PRAGMA journal_mode = DELETE');
      _setCipher(raw);
      raw.execute('PRAGMA rekey = "x\'$hexKey\'"');
    } finally {
      raw.close();
    }
  }
}
