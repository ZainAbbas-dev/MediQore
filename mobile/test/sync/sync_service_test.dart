import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/data/household_repository.dart';
import 'package:mediqore/sync/sync_api.dart';
import 'package:mediqore/sync/sync_service.dart';

import '../support/fake_sync_server.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late HouseholdRepository households;
  late FakeSyncServer server;
  late SyncService sync;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    households = HouseholdRepository(db);
    server = FakeSyncServer()
      ..approve('device-1')
      ..validAccessTokens.add('token-1');
    sync = SyncService(db: db, api: SyncApi(client: server.client, baseUrl: 'http://test/api/v1'), deviceId: 'device-1');
  });

  tearDown(() => db.close());

  test('creating a household writes the record and its outbox entry together', () async {
    final h = await households.create(village: 'Test village', latitude: 33.6844, longitude: 73.0479);

    expect(await households.all(), hasLength(1));
    final queued = await db.select(db.outbox).getSingle();
    expect(queued.recordId, h.id);
    final payload = jsonDecode(queued.payload) as Map<String, dynamic>;
    expect(payload, containsPair('table', 'households'));
    expect(payload['data'], containsPair('village', 'Test village'));
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(h.id), isTrue,
        reason: 'ids are UUID v4 made on the device');
  });

  test('sync pushes the outbox, stores server numbers and empties the queue', () async {
    final h = await households.create(village: 'Test village');

    final report = await sync.syncNow('token-1');

    expect(report.pushed, 1);
    expect(await db.pendingCount(), 0);
    final stored = (await households.all()).single;
    expect(stored.serverSeq, server.records[h.id]!['serverSeq']);
    expect(report.lastServerSeq, stored.serverSeq);
  });

  test('pushes as this phone, which the server must have approved (M1 FE-2)', () async {
    await households.create(village: 'Test village');
    final unapproved = SyncService(db: db, api: SyncApi(client: server.client, baseUrl: 'http://test/api/v1'), deviceId: 'device-2');

    await expectLater(
      unapproved.syncNow('token-1'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'DEVICE_NOT_ALLOWED')),
    );
    expect(await db.pendingCount(), 1, reason: 'nothing is lost');
  });

  test('pushes in batches of at most 100', () async {
    for (var i = 0; i < 150; i++) {
      await households.create(village: 'V$i');
    }

    await sync.syncNow('token-1');

    expect(server.pushedBatches.map((b) => b.length), [100, 50]);
    expect(await db.pendingCount(), 0);
  });

  test('pulls records made on other phones and remembers how far it got', () async {
    server.addFromAnotherDevice('0b7f8e2a-3c4d-4e5f-8a9b-1c2d3e4f5a6b', 'Other village');

    final report = await sync.syncNow('token-1');

    expect(report.pulled, 1);
    expect((await households.all()).single.village, 'Other village');
    expect(await sync.lastServerSeq(), 1);

    final again = await sync.syncNow('token-1');
    expect(again.pulled, 0);
  });

  test('a refused record stays on the phone, marked, and stops blocking the queue', () async {
    final refused = await households.create(village: 'Refused');
    await households.create(village: 'Accepted');
    server.rejectIds.add(refused.id);

    final report = await sync.syncNow('token-1');

    expect(report.rejected, 1);
    expect(report.pushed, 1);
    expect(await db.pendingCount(), 0);
    final entry = await db.select(db.outbox).getSingle();
    expect(entry.recordId, refused.id);
    expect(entry.lastError, 'OUT_OF_AREA');

    await sync.syncNow('token-1');
    expect(server.pushedBatches, hasLength(1), reason: 'refused records are not pushed again');
  });

  test('without a network nothing is lost; the next sync sends it', () async {
    await households.create(village: 'Offline');
    server.offline = true;

    await expectLater(sync.syncNow('token-1'), throwsA(isA<http.ClientException>()));
    expect(await db.pendingCount(), 1);

    server.offline = false;
    await sync.syncNow('token-1');
    expect(await db.pendingCount(), 0);
  });

  test('a rejected token surfaces as ApiException and keeps the outbox', () async {
    await households.create(village: 'X');

    await expectLater(
      sync.syncNow('bad-token'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'UNAUTHORIZED')),
    );
    expect(await db.pendingCount(), 1);
  });
}
