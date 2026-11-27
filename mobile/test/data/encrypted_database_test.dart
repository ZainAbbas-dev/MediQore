import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/database_opener.dart';
import 'package:mediqore/data/household_repository.dart';
import 'package:mediqore/sync/sync_api.dart';
import 'package:mediqore/sync/sync_service.dart';

import '../support/fake_sync_server.dart';

/// The real encrypted file (M3 FE-2, LI-8): what is on the disk, and what a
/// wrong key, an older unencrypted database, a new key and a reset do.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory folder;
  late EncryptedDatabaseOpener opener;
  late File file;

  final keyA = Uint8List.fromList(List.generate(32, (i) => i));
  final keyB = Uint8List.fromList(List.generate(32, (i) => 255 - i));

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('mediqore_db_');
    opener = EncryptedDatabaseOpener(directory: () async => folder, tempDirectory: () async => null);
    file = File('${folder.path}/${EncryptedDatabaseOpener.fileName}');
  });
  tearDown(() => folder.delete(recursive: true));

  bool fileShows(String text) => String.fromCharCodes(file.readAsBytesSync()).contains(text);

  test('records are unreadable on the disk and open only with the same key', () async {
    var db = await opener.open(keyA);
    await HouseholdRepository(db).create(village: 'Synthetic village 7');
    await opener.close(db);

    expect(file.existsSync(), isTrue);
    expect(fileShows('Synthetic village 7'), isFalse);
    expect(fileShows('SQLite format 3'), isFalse, reason: 'not even the SQLite header is readable');
    await expectLater(opener.open(keyB), throwsA(isA<WrongDatabaseKey>()));

    db = await opener.open(keyA);
    expect((await HouseholdRepository(db).all()).single.village, 'Synthetic village 7');
    await opener.close(db);
  });

  test('a pending operation survives an encrypted database reopen after a lost reply', () async {
    final server = FakeSyncServer()
      ..activate('device-1')
      ..validAccessTokens.add('token-1')
      ..afterPush = (() async => throw http.ClientException('response lost'));
    final api = SyncApi(client: server.client, baseUrl: 'http://test/api/v1');
    var db = await opener.open(keyA);
    await HouseholdRepository(db).create(village: 'Synthetic restart village');
    await expectLater(SyncService(db: db, api: api, deviceId: 'device-1').syncNow('token-1'), throwsException);
    final first = server.pushedBatches.single.single;
    await opener.close(db);

    expect(fileShows(first['operationId'] as String), isFalse);
    db = await opener.open(keyA);
    expect(await db.pendingCount(), 1);
    await SyncService(db: db, api: api, deviceId: 'device-1').syncNow('token-1');
    expect(server.pushedBatches.last.single, first);
    expect(await db.pendingCount(), 0);
    await opener.close(db);
  });

  test('an unencrypted database from an earlier version is encrypted in place, keeping its records', () async {
    final plain = AppDatabase(NativeDatabase(file));
    await HouseholdRepository(plain).create(village: 'Made before encryption');
    await plain.close();
    expect(fileShows('Made before encryption'), isTrue);
    expect(await opener.readablePendingCount(), 1, reason: 'an unencrypted outbox can be counted without a key');

    final db = await opener.open(keyA);
    expect((await HouseholdRepository(db).all()).single.village, 'Made before encryption');
    expect(await db.pendingCount(), 1);
    await opener.close(db);

    expect(fileShows('Made before encryption'), isFalse);
    expect(await opener.readablePendingCount(), isNull, reason: 'encrypted now');
  });

  test('rekey moves the database to a new key, keeping its records (an earlier version at activation)', () async {
    var db = await opener.open(keyA);
    await HouseholdRepository(db).create(village: 'Made with the password key');
    await opener.close(db);

    await expectLater(opener.rekey(keyB, keyA), throwsA(isA<WrongDatabaseKey>()));
    await opener.rekey(keyA, keyB);

    await expectLater(opener.open(keyA), throwsA(isA<WrongDatabaseKey>()));
    db = await opener.open(keyB);
    expect((await HouseholdRepository(db).all()).single.village, 'Made with the password key');
    await opener.close(db);
    expect(fileShows('Made with the password key'), isFalse);
  });

  test('rekey of a missing database is refused', () async {
    await expectLater(opener.rekey(keyA, keyB), throwsA(isA<WrongDatabaseKey>()));
  });

  test('destroy removes the database; the next open starts empty', () async {
    var db = await opener.open(keyA);
    await HouseholdRepository(db).create(village: 'Old');
    await opener.close(db);

    await opener.destroy();

    expect(file.existsSync(), isFalse);
    expect(await opener.readablePendingCount(), 0);
    db = await opener.open(keyB);
    expect(await HouseholdRepository(db).all(), isEmpty);
    await opener.close(db);
  });
}
