import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';

/// Writes households locally. Every write also queues the record in the outbox
/// in the same transaction, so nothing saved offline is ever left unsynced
/// (roadmap, Offline sync).
class HouseholdRepository {
  HouseholdRepository(this._db, {this._uuid = const Uuid(), DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const String table = 'households';

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  Future<LocalHousehold> create({
    String? householdNumber,
    String? address,
    String? village,
    double? latitude,
    double? longitude,
  }) {
    final household = LocalHousehold(
      id: _uuid.v4(),
      householdNumber: householdNumber,
      address: address,
      village: village,
      latitude: latitude,
      longitude: longitude,
      createdOnDevice: _clock().toUtc(),
    );
    return _db.transaction(() async {
      await _db.into(_db.households).insert(household);
      await _enqueue(household);
      return household;
    });
  }

  Future<List<LocalHousehold>> all() => (_db.select(_db.households)
        ..where((h) => h.deletedAt.isNull())
        ..orderBy([(h) => OrderingTerm.asc(h.createdOnDevice)]))
      .get();

  Future<void> _enqueue(LocalHousehold household) {
    final payload = {
      'table': table,
      'id': household.id,
      'createdOnDevice': household.createdOnDevice.toUtc().toIso8601String(),
      'deleted': household.deletedAt != null,
      'data': {
        'householdNumber': household.householdNumber,
        'address': household.address,
        'village': household.village,
        'latitude': household.latitude,
        'longitude': household.longitude,
      },
    };
    return _db.into(_db.outbox).insert(
          OutboxCompanion.insert(
            entityTable: table,
            recordId: household.id,
            payload: jsonEncode(payload),
            queuedAt: _clock().toUtc(),
          ),
          onConflict: DoUpdate(
            (_) => OutboxCompanion(
              payload: Value(jsonEncode(payload)),
              attempts: const Value(0),
              lastError: const Value(null),
              queuedAt: Value(_clock().toUtc()),
            ),
            target: [_db.outbox.entityTable, _db.outbox.recordId],
          ),
        );
  }
}
