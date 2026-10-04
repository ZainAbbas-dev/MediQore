// M3 FE-1: recording a home visit, offline. The visit and its outbox entry are
// written in one transaction (roadmap, Offline sync). The vitals are stored in
// their one unit each and never converted here.
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../auth/local_account.dart';
import 'app_database.dart';
import 'patient_repository.dart';

/// What the visit form collects (M3 FE-1). Units: BP in mmHg, weight in kg,
/// temperature in °C, pulse in beats per minute, blood sugar in mmol/L.
class VisitInput {
  const VisitInput({
    required this.pregnancyId,
    this.systolicBpMmhg,
    this.diastolicBpMmhg,
    this.weightKg,
    this.temperatureC,
    this.pulseBpm,
    this.bloodSugarMmolL,
    this.fetalMovement,
    this.swelling = false,
    this.bleeding = false,
    this.fever = false,
    this.anaemiaSigns = 'none',
    this.urineSymptoms = false,
  });

  final String pregnancyId;
  final int? systolicBpMmhg;
  final int? diastolicBpMmhg;
  final double? weightKg;
  final double? temperatureC;
  final int? pulseBpm;
  final double? bloodSugarMmolL;

  /// normal, reduced or absent; null when not assessed.
  final String? fetalMovement;
  final bool swelling;
  final bool bleeding;
  final bool fever;

  /// none, present or severe.
  final String anaemiaSigns;
  final bool urineSymptoms;
}

/// A visit with whether it has reached the server.
class VisitSummary {
  const VisitSummary({required this.visit, required this.syncStatus});

  final LocalVisit visit;
  final SyncStatus syncStatus;
}

class VisitRepository {
  VisitRepository(this._db, {this._uuid = const Uuid(), DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const String table = 'visits';

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// Saves a visit made by [by] and queues it for the next sync. The visit
  /// time is the phone's clock: shown to people, never used to order or
  /// resolve records (LI-7).
  Future<LocalVisit> record(VisitInput input, {required SessionUser by}) async {
    // Whole seconds, so the time reads back exactly as it was pushed.
    final now = DateTime.fromMillisecondsSinceEpoch(_clock().millisecondsSinceEpoch ~/ 1000 * 1000);
    final visit = LocalVisit(
      id: _uuid.v4(),
      areaId: by.areaId,
      createdBy: by.id,
      createdOnDevice: now.toUtc(),
      pregnancyId: input.pregnancyId,
      visitedAt: now.toUtc(),
      systolicBpMmhg: input.systolicBpMmhg,
      diastolicBpMmhg: input.diastolicBpMmhg,
      weightKg: input.weightKg,
      temperatureC: input.temperatureC,
      pulseBpm: input.pulseBpm,
      bloodSugarMmolL: input.bloodSugarMmolL,
      fetalMovement: input.fetalMovement,
      swelling: input.swelling,
      bleeding: input.bleeding,
      fever: input.fever,
      anaemiaSigns: input.anaemiaSigns,
      urineSymptoms: input.urineSymptoms,
    );
    return _db.transaction(() async {
      await _db.into(_db.visits).insert(visit);
      await _db.enqueue(payloadOf(visit), queuedAt: now);
      return visit;
    });
  }

  /// The visits of one pregnancy, the latest first. "Latest" is the order the
  /// server numbered them, then the visits not synced yet in the order they were
  /// saved on this phone; never the phone's clock (LI-7).
  Future<List<VisitSummary>> forPregnancy(String pregnancyId) async {
    final visits = await (_db.select(_db.visits)
          ..where((v) => v.pregnancyId.equals(pregnancyId) & v.deletedAt.isNull())
          ..orderBy([
            (v) => OrderingTerm.asc(v.serverSeq.isNull()),
            (v) => OrderingTerm.asc(v.serverSeq),
            (v) => OrderingTerm.asc(v.rowId),
          ]))
        .get();
    final queued = {
      for (final e in await (_db.select(_db.outbox)..where((o) => o.entityTable.equals(table))).get()) e.recordId: e,
    };
    return [
      for (final visit in visits.reversed)
        VisitSummary(visit: visit, syncStatus: _statusOf(visit, queued[visit.id])),
    ];
  }

  static SyncStatus _statusOf(LocalVisit visit, OutboxEntry? queued) {
    if (queued != null) return queued.lastError == null ? SyncStatus.waiting : SyncStatus.refused;
    if (visit.conflictId != null) return SyncStatus.held;
    return SyncStatus.synced;
  }

  /// The visit as `/sync/push` takes it (docs/openapi.yaml, VisitData).
  static Map<String, Object?> payloadOf(LocalVisit v) => syncPayload(
        table: table,
        id: v.id,
        areaId: v.areaId,
        createdOnDevice: v.createdOnDevice,
        deletedAt: v.deletedAt,
        data: {
          'pregnancyId': v.pregnancyId,
          'visitedAt': v.visitedAt.toUtc().toIso8601String(),
          'systolicBpMmhg': v.systolicBpMmhg,
          'diastolicBpMmhg': v.diastolicBpMmhg,
          'weightKg': v.weightKg,
          'temperatureC': v.temperatureC,
          'pulseBpm': v.pulseBpm,
          'bloodSugarMmolL': v.bloodSugarMmolL,
          'fetalMovement': v.fetalMovement,
          'swelling': v.swelling,
          'bleeding': v.bleeding,
          'fever': v.fever,
          'anaemiaSigns': v.anaemiaSigns,
          'urineSymptoms': v.urineSymptoms,
        },
      );
}
