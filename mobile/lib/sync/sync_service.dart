// M3 FE-2: offline sync skeleton on the device (P0-6).
import 'dart:convert';

import 'package:drift/drift.dart';

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
  SyncService({required this._db, required this._api, required this.deviceId});

  static const int batchSize = 100;
  static const String lastServerSeqKey = AppDatabase.lastServerSeqKey;

  final AppDatabase _db;
  final SyncApi _api;

  /// The installation's UUID (AppSettings.deviceId), sent with every push. The
  /// server accepts only the approved phone the token was issued to (M1 FE-2).
  final String deviceId;

  Future<int> lastServerSeq() async => int.parse(await _db.readState(lastServerSeqKey) ?? '0');

  /// Pushes everything waiting, then pulls. Throws [ApiException] or a network
  /// error if the server cannot be reached; nothing is lost, the outbox stays.
  Future<SyncReport> syncNow(String token) async {
    final (pushed, rejected) = await push(token);
    final pulled = await pull(token);
    return SyncReport(pushed: pushed, rejected: rejected, pulled: pulled, lastServerSeq: await lastServerSeq());
  }

  /// Pushes the outbox; returns how many records were accepted and refused.
  Future<(int, int)> push(String token) async {
    final device = deviceId;
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
    await _db.setServerSeq(entry.entityTable, entry.recordId, serverSeq);
  }

  /// Pulls everything after the last server number seen; returns how many records came.
  Future<int> pull(String token) async {
    var since = await lastServerSeq();
    var pulled = 0;
    while (true) {
      final page = await _api.pull(token, since, limit: batchSize);
      await _db.transaction(() async {
        for (final record in page.records) {
          await _apply(record);
        }
        await _db.writeState(lastServerSeqKey, '${page.nextSince}');
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

    final d = record.data;
    final createdOnDevice = record.createdOnDevice ?? DateTime.now().toUtc();
    final deletedAt = Value(record.deleted ? DateTime.now().toUtc() : null);
    final areaId = Value(record.areaId);
    // No parent is required: an edited household is numbered after its women,
    // so a woman can arrive first (docs/openapi.yaml, syncPull).
    switch (record.table) {
      case 'households':
        await _db.into(_db.households).insertOnConflictUpdate(
              HouseholdsCompanion.insert(
                id: record.id,
                serverSeq: Value(record.serverSeq),
                areaId: areaId,
                householdNumber: Value(d['householdNumber'] as String?),
                address: Value(d['address'] as String?),
                village: Value(d['village'] as String?),
                latitude: Value((d['latitude'] as num?)?.toDouble()),
                longitude: Value((d['longitude'] as num?)?.toDouble()),
                createdOnDevice: createdOnDevice,
                deletedAt: deletedAt,
              ),
            );
      case 'women':
        await _db.into(_db.women).insertOnConflictUpdate(
              WomenCompanion.insert(
                id: record.id,
                serverSeq: Value(record.serverSeq),
                areaId: areaId,
                createdOnDevice: createdOnDevice,
                deletedAt: deletedAt,
                householdId: d['householdId'] as String,
                patientCode: d['patientCode'] as String,
                name: d['name'] as String,
                age: Value(d['age'] as int?),
                husbandName: Value(d['husbandName'] as String?),
                contactNumber: Value(d['contactNumber'] as String?),
              ),
            );
      case 'pregnancies':
        await _db.into(_db.pregnancies).insertOnConflictUpdate(
              PregnanciesCompanion.insert(
                id: record.id,
                serverSeq: Value(record.serverSeq),
                areaId: areaId,
                createdOnDevice: createdOnDevice,
                deletedAt: deletedAt,
                womanId: d['womanId'] as String,
                registeredOn: d['registeredOn'] as String,
                pregnancyMonthAtRegistration: d['pregnancyMonthAtRegistration'] as int,
                status: Value(d['status'] as String? ?? 'active'),
                closedOn: Value(d['closedOn'] as String?),
              ),
            );
      case 'obstetric_history':
        await _db.into(_db.obstetricHistory).insertOnConflictUpdate(
              ObstetricHistoryCompanion.insert(
                id: record.id,
                serverSeq: Value(record.serverSeq),
                areaId: areaId,
                createdOnDevice: createdOnDevice,
                deletedAt: deletedAt,
                womanId: d['womanId'] as String,
                previousPregnancies: Value(d['previousPregnancies'] as int? ?? 0),
                previousCSections: Value(d['previousCSections'] as int? ?? 0),
                stillbirths: Value(d['stillbirths'] as int? ?? 0),
                knownConditions: Value(d['knownConditions'] as String?),
              ),
            );
      default:
        // Tables added by later modules are applied here as they are built.
        break;
    }
  }
}
