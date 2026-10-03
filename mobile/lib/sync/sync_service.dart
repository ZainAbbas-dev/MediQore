// M3 FE-2: offline sync skeleton on the device (P0-6).
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/app_database.dart';
import 'sync_api.dart';

/// What one sync run did, for the status shown to the LHW.
class SyncReport {
  const SyncReport({required this.pushed, required this.rejected, required this.pulled, required this.lastServerSeq});

  final int pushed;
  final int rejected;
  final int pulled;
  final int lastServerSeq;
}

/// Pushes the outbox and pulls changes for the LHW's area, following the
/// roadmap's Offline sync track:
/// - push sends the outbox in batches of up to 100, highest priority first;
/// - the server answers with the sequence number it gave each record;
/// - pull asks for everything after the last sequence number seen, so nothing
///   depends on the phone's clock (LI-7).
class SyncService {
  SyncService({required this._db, required this._api, this._uuid = const Uuid()});

  static const int batchSize = 100;
  static const String _deviceIdKey = 'device_id';
  static const String _lastServerSeqKey = 'last_server_seq';

  final AppDatabase _db;
  final SyncApi _api;
  final Uuid _uuid;

  /// The installation's UUID, created on first use and sent with every push.
  Future<String> deviceId() async {
    final existing = await _db.readState(_deviceIdKey);
    if (existing != null) return existing;
    final id = _uuid.v4();
    await _db.writeState(_deviceIdKey, id);
    return id;
  }

  Future<int> lastServerSeq() async => int.parse(await _db.readState(_lastServerSeqKey) ?? '0');

  /// Pushes everything waiting, then pulls. Throws [ApiException] or a network
  /// error if the server cannot be reached; nothing is lost, the outbox stays.
  Future<SyncReport> syncNow(String token) async {
    final (pushed, rejected) = await _pushAll(token);
    final pulled = await _pullAll(token);
    return SyncReport(pushed: pushed, rejected: rejected, pulled: pulled, lastServerSeq: await lastServerSeq());
  }

  Future<(int, int)> _pushAll(String token) async {
    final device = await deviceId();
    var pushed = 0;
    var rejected = 0;
    while (true) {
      final batch = await (_db.select(_db.outbox)
            ..where((o) => o.lastError.isNull())
            ..orderBy([(o) => OrderingTerm.desc(o.priority), (o) => OrderingTerm.asc(o.id)])
            ..limit(batchSize))
          .get();
      if (batch.isEmpty) return (pushed, rejected);

      final results = await _api.push(token, device, [for (final entry in batch) jsonDecode(entry.payload) as Map<String, dynamic>]);

      await _db.transaction(() async {
        for (final (index, entry) in batch.indexed) {
          final result = results[index];
          if (result['status'] == 'rejected') {
            rejected++;
            await (_db.update(_db.outbox)..where((o) => o.id.equals(entry.id))).write(
              OutboxCompanion(lastError: Value(result['reason'] as String? ?? 'rejected'), attempts: Value(entry.attempts + 1)),
            );
            continue;
          }
          pushed++;
          await _markAccepted(entry, result['serverSeq'] as int);
        }
      });
    }
  }

  // Removes the outbox entry and stores the server's sequence number, unless the
  // record was edited again while the push was in flight (the entry was replaced):
  // then the newer version stays queued for the next push.
  Future<void> _markAccepted(OutboxEntry entry, int serverSeq) async {
    final removed = await (_db.delete(_db.outbox)
          ..where((o) => o.id.equals(entry.id) & o.payload.equals(entry.payload)))
        .go();
    if (removed == 0) return;
    if (entry.entityTable == 'households') {
      await (_db.update(_db.households)..where((h) => h.id.equals(entry.recordId)))
          .write(HouseholdsCompanion(serverSeq: Value(serverSeq)));
    }
  }

  Future<int> _pullAll(String token) async {
    var since = await lastServerSeq();
    var pulled = 0;
    while (true) {
      final page = await _api.pull(token, since, limit: batchSize);
      await _db.transaction(() async {
        for (final record in page.records) {
          await _apply(record);
        }
        await _db.writeState(_lastServerSeqKey, '${page.nextSince}');
      });
      pulled += page.records.length;
      since = page.nextSince;
      if (!page.hasMore) return pulled;
    }
  }

  Future<void> _apply(PulledRecord record) async {
    // A local change that is still queued is newer than the server copy; it wins
    // until it has been pushed.
    final queued = await (_db.select(_db.outbox)
          ..where((o) => o.entityTable.equals(record.table) & o.recordId.equals(record.id) & o.lastError.isNull()))
        .getSingleOrNull();
    if (queued != null) return;

    switch (record.table) {
      case 'households':
        final d = record.data;
        await _db.into(_db.households).insertOnConflictUpdate(
              HouseholdsCompanion.insert(
                id: record.id,
                serverSeq: Value(record.serverSeq),
                householdNumber: Value(d['householdNumber'] as String?),
                address: Value(d['address'] as String?),
                village: Value(d['village'] as String?),
                latitude: Value((d['latitude'] as num?)?.toDouble()),
                longitude: Value((d['longitude'] as num?)?.toDouble()),
                createdOnDevice: record.createdOnDevice ?? DateTime.now().toUtc(),
                deletedAt: Value(record.deleted ? DateTime.now().toUtc() : null),
              ),
            );
      default:
        // Tables added by later modules are applied here as they are built.
        break;
    }
  }
}
