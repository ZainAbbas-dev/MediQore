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

  /// [areaId] is the area the household is in: the signed-in LHW's area
  /// (M1 FE-3). [createdBy] is the signed-in user.
  Future<LocalHousehold> create({
    String? householdNumber,
    String? address,
    String? village,
    double? latitude,
    double? longitude,
    String? areaId,
    String? createdBy,
  }) {
    final household = LocalHousehold(
      id: _uuid.v4(),
      householdNumber: householdNumber,
      address: address,
      village: village,
      latitude: latitude,
      longitude: longitude,
      createdOnDevice: _clock().toUtc(),
      areaId: areaId,
      createdBy: createdBy,
    );
    return _db.transaction(() async {
      await _db.into(_db.households).insert(household);
      await _db.enqueue(payloadOf(household), queuedAt: _clock());
      return household;
    });
  }

  /// Records the home's GPS position (M2 FE-3), for example when it could not
  /// be found at registration.
  Future<LocalHousehold> setLocation(String id, {required double latitude, required double longitude}) {
    return _db.transaction(() async {
      final current = await (_db.select(_db.households)..where((h) => h.id.equals(id))).getSingle();
      final updated = current.copyWith(latitude: Value(latitude), longitude: Value(longitude));
      await _db.update(_db.households).replace(updated);
      await _db.enqueue(payloadOf(updated), queuedAt: _clock());
      return updated;
    });
  }

  Future<List<LocalHousehold>> all() => (_db.select(_db.households)
        ..where((h) => h.deletedAt.isNull())
        ..orderBy([(h) => OrderingTerm.asc(h.createdOnDevice)]))
      .get();

  /// The household as `/sync/push` takes it.
  static Map<String, Object?> payloadOf(LocalHousehold household) => syncPayload(
        table: table,
        id: household.id,
        areaId: household.areaId,
        createdOnDevice: household.createdOnDevice,
        deletedAt: household.deletedAt,
        data: {
          'householdNumber': household.householdNumber,
          'address': household.address,
          'village': household.village,
          'latitude': household.latitude,
          'longitude': household.longitude,
        },
      );
}
