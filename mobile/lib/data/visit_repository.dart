// M3 FE-1: recording a home visit, offline. The visit and its outbox entry are
// written in one transaction (roadmap, Offline sync). The vitals are stored in
// their one unit each and never converted here.
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../auth/local_account.dart';
import 'app_database.dart';
import 'patient_repository.dart';

/// What the visit form collects (M3 FE-1). Units: BP in mmHg, weight in kg,
/// temperature in °C, pulse in beats per minute, blood sugar in the unit it was
/// recorded in (with that unit, the day measured and the source). The danger-sign checklist
/// answers are null only for a visit where they were not asked.
class VisitInput {
  const VisitInput({
    required this.pregnancyId,
    this.systolicBpMmhg,
    this.diastolicBpMmhg,
    this.weightKg,
    this.temperatureC,
    this.pulseBpm,
    this.bloodSugarValue,
    this.bloodSugarUnit,
    this.bloodSugarMeasuredOn,
    this.bloodSugarSource,
    this.fetalMovement,
    this.swelling = false,
    this.bleeding = false,
    this.fever = false,
    this.anaemiaSigns = 'none',
    this.urineSymptoms = false,
    this.convulsions,
    this.severeHeadache,
    this.blurredVision,
    this.severeAbdominalPain,
    this.fastBreathing,
    this.feverWithWeakness,
  });

  final String pregnancyId;
  final int? systolicBpMmhg;
  final int? diastolicBpMmhg;
  final double? weightKg;
  final double? temperatureC;
  final int? pulseBpm;
  /// Blood sugar in the unit it was recorded in (M3 FE-1).
  final double? bloodSugarValue;

  /// mmol_l or mg_dl.
  final String? bloodSugarUnit;

  /// YYYY-MM-DD.
  final String? bloodSugarMeasuredOn;

  /// glucometer or lab_report.
  final String? bloodSugarSource;

  /// normal, reduced or absent; null when not assessed.
  final String? fetalMovement;
  final bool swelling;
  final bool bleeding;
  final bool fever;

  /// none, present or severe.
  final String anaemiaSigns;
  final bool urineSymptoms;

  final bool? convulsions;
  final bool? severeHeadache;
  final bool? blurredVision;
  final bool? severeAbdominalPain;
  final bool? fastBreathing;
  final bool? feverWithWeakness;
}

/// A visit with whether it has reached the server.
class VisitSummary {
  const VisitSummary({required this.visit, required this.syncStatus});

  final LocalVisit visit;
  final SyncStatus syncStatus;
}

/// A visit with the woman it belongs to (null if her record is not on the phone).
class RecentVisit {
  const RecentVisit({required this.summary, this.woman});

  final VisitSummary summary;
  final LocalWoman? woman;
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
      bloodSugarValue: input.bloodSugarValue,
      bloodSugarUnit: input.bloodSugarValue == null ? null : input.bloodSugarUnit,
      bloodSugarMeasuredOn: input.bloodSugarValue == null ? null : input.bloodSugarMeasuredOn,
      bloodSugarSource: input.bloodSugarValue == null ? null : input.bloodSugarSource,
      fetalMovement: input.fetalMovement,
      swelling: input.swelling,
      bleeding: input.bleeding,
      fever: input.fever,
      anaemiaSigns: input.anaemiaSigns,
      urineSymptoms: input.urineSymptoms,
      convulsions: input.convulsions,
      severeHeadache: input.severeHeadache,
      blurredVision: input.blurredVision,
      severeAbdominalPain: input.severeAbdominalPain,
      fastBreathing: input.fastBreathing,
      feverWithWeakness: input.feverWithWeakness,
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

  /// The latest visits on this phone, for the home screen: the ones not synced
  /// yet, the last saved first, then the ones the server numbered last. Never
  /// ordered by the phone's clock (LI-7).
  Future<List<RecentVisit>> recent({int limit = 5}) async {
    final visits = await (_db.select(_db.visits)
          ..where((v) => v.deletedAt.isNull())
          ..orderBy([
            (v) => OrderingTerm.desc(v.serverSeq.isNull()),
            (v) => OrderingTerm.desc(v.serverSeq),
            (v) => OrderingTerm.desc(v.rowId),
          ])
          ..limit(limit))
        .get();
    if (visits.isEmpty) return const [];
    final pregnancies = {
      for (final p in await (_db.select(_db.pregnancies)..where((p) => p.id.isIn(visits.map((v) => v.pregnancyId)))).get())
        p.id: p,
    };
    final women = {
      for (final w in await (_db.select(_db.women)..where((w) => w.id.isIn(pregnancies.values.map((p) => p.womanId)))).get())
        w.id: w,
    };
    final queued = {
      for (final e in await (_db.select(_db.outbox)..where((o) => o.entityTable.equals(table))).get()) e.recordId: e,
    };
    return [
      for (final visit in visits)
        RecentVisit(
          summary: VisitSummary(visit: visit, syncStatus: _statusOf(visit, queued[visit.id])),
          woman: women[pregnancies[visit.pregnancyId]?.womanId],
        ),
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
      'bloodSugarValue': v.bloodSugarValue,
      'bloodSugarUnit': v.bloodSugarUnit,
      'bloodSugarMeasuredOn': v.bloodSugarMeasuredOn,
      'bloodSugarSource': v.bloodSugarSource,
      'fetalMovement': v.fetalMovement,
      'swelling': v.swelling,
      'bleeding': v.bleeding,
      'fever': v.fever,
      'anaemiaSigns': v.anaemiaSigns,
      'urineSymptoms': v.urineSymptoms,
      'convulsions': v.convulsions,
      'severeHeadache': v.severeHeadache,
      'blurredVision': v.blurredVision,
      'severeAbdominalPain': v.severeAbdominalPain,
      'fastBreathing': v.fastBreathing,
      'feverWithWeakness': v.feverWithWeakness,
    },
  );
}
