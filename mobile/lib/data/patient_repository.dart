// M2 FE-1, FE-2, FE-3: registering a pregnant woman, offline. One registration
// writes the household (or reuses one), the woman, her pregnancy file and her
// obstetric history, each with its outbox entry, in a single transaction.
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../auth/local_account.dart';
import '../clinical/gestational_age.dart';
import '../location/distance.dart';
import 'app_database.dart';
import 'household_repository.dart';

/// Pregnancy dating and history shared by new and returning patients.
class PregnancyInput {
  const PregnancyInput({
    required this.pregnancyMonth,
    this.estimatedDeliveryDate,
    this.eddBasis = EddBasis.month,
    this.lmpDate,
    this.reportedEdd,
    this.previousPregnancies = 0,
    this.previousCSections = 0,
    this.stillbirths = 0,
    this.knownConditions,
  });

  final int pregnancyMonth;
  final DateTime? estimatedDeliveryDate;
  final EddBasis eddBasis;
  final DateTime? lmpDate;
  final DateTime? reportedEdd;
  final int previousPregnancies;
  final int previousCSections;
  final int stillbirths;
  final String? knownConditions;
}

/// What the new patient form collects (M2 FE-1, FE-2, FE-3).
class RegistrationInput extends PregnancyInput {
  const RegistrationInput({
    required this.name,
    required this.age,
    this.husbandName,
    this.contactNumber,
    required super.pregnancyMonth,
    super.estimatedDeliveryDate,
    super.eddBasis,
    super.lmpDate,
    super.reportedEdd,
    this.householdId,
    this.householdNumber,
    this.village,
    this.address,
    this.latitude,
    this.longitude,
    super.previousPregnancies,
    super.previousCSections,
    super.stillbirths,
    super.knownConditions,
  });

  final String name;
  final int age;
  final String? husbandName;
  final String? contactNumber;

  /// An existing home, or new household details if absent.
  final String? householdId;
  final String? householdNumber;
  final String? village;
  final String? address;
  final double? latitude;
  final double? longitude;
}

/// Whether a record has reached the server.
enum SyncStatus {
  synced,
  waiting,
  refused,

  /// The server holds the record for a supervisor's review: an edit made on an
  /// older version than the server's (M3 FE-2).
  held,
}

/// One line of the patient list.
class PatientSummary {
  const PatientSummary({required this.woman, this.household, this.pregnancy, required this.syncStatus, this.distanceKm});

  final LocalWoman woman;
  final LocalHousehold? household;

  /// The active pregnancy, or the latest one.
  final LocalPregnancy? pregnancy;
  final SyncStatus syncStatus;

  /// The straight-line distance from the LHW to the home, when the list was
  /// sorted by distance and the home has a GPS position (M2 FE-3).
  final double? distanceKm;

  String? get village => household?.village;
}

/// Everything the phone holds about one woman: her digital pregnancy file.
class PatientFile {
  const PatientFile({required this.woman, this.household, this.pregnancy, this.history, required this.syncStatus});

  final LocalWoman woman;
  final LocalHousehold? household;
  final LocalPregnancy? pregnancy;
  final LocalObstetricHistory? history;
  final SyncStatus syncStatus;
}

class PatientCodeChanged implements Exception {
  const PatientCodeChanged(this.code);
  final String code;
}

class PatientRepository {
  PatientRepository(this._db, {this._uuid = const Uuid(), DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  static String _patientCode(String prefix, int number) => '$prefix${number.toString().padLeft(4, '0')}';

  Future<String> nextPatientCode(SessionUser user) async {
    final prefix = user.patientCodePrefix;
    if (prefix == null) throw StateError('Only an LHW can register a woman');
    return _patientCode(prefix, await _db.nextPatientNumber(prefix, legacy: user.activationNumber == null));
  }

  /// Saves a registration made by [by], an LHW, and returns the woman with
  /// her new patient ID, [LHW code]-[activation number]-[sequence], made on
  /// this phone so it is unique before the first sync (M2 FE-1).
  Future<LocalWoman> register(RegistrationInput input, {required SessionUser by, String? expectedCode}) async {
    final prefix = by.patientCodePrefix;
    if (prefix == null) throw StateError('Only an LHW can register a woman');
    final now = _clock();
    final createdOnDevice = now.toUtc();

    return _db.transaction(() async {
      final existingId = input.householdId;
      final String householdId;
      if (existingId == null) {
        final household = LocalHousehold(
          id: _uuid.v4(),
          householdNumber: input.householdNumber,
          village: input.village,
          address: input.address,
          latitude: input.latitude,
          longitude: input.longitude,
          createdOnDevice: createdOnDevice,
          areaId: by.areaId,
          createdBy: by.id,
        );
        await _db.into(_db.households).insert(household);
        await _db.enqueue(HouseholdRepository.payloadOf(household), queuedAt: now);
        householdId = household.id;
      } else {
        final home = await (_db.select(_db.households)
              ..where((h) => h.id.equals(existingId) & h.deletedAt.isNull()))
            .getSingleOrNull();
        if (home == null || home.areaId != by.areaId) throw StateError('Household is not in the LHW’s area');
        householdId = existingId;
      }

      final number = await _db.takePatientNumber(prefix, legacy: by.activationNumber == null);
      final code = _patientCode(prefix, number);
      if (expectedCode != null && expectedCode != code) throw PatientCodeChanged(code);
      final woman = LocalWoman(
        id: _uuid.v4(),
        areaId: by.areaId,
        createdBy: by.id,
        createdOnDevice: createdOnDevice,
        householdId: householdId,
        patientCode: code,
        name: input.name,
        age: input.age,
        husbandName: input.husbandName,
        contactNumber: input.contactNumber,
      );
      await _db.into(_db.women).insert(woman);
      await _db.enqueue(womanPayload(woman), queuedAt: now);

      await _writePregnancy(woman, input, by, now);
      return woman;
    });
  }

  /// Opens a new file for a woman whose previous pregnancy is closed.
  Future<LocalWoman> startPregnancy(String womanId, PregnancyInput input, {required SessionUser by}) {
    return _db.transaction(() async {
      final woman = await (_db.select(_db.women)
            ..where((w) => w.id.equals(womanId) & w.deletedAt.isNull()))
          .getSingleOrNull();
      if (by.patientCodePrefix == null || woman == null || woman.areaId != by.areaId) {
        throw StateError('A pregnancy can only be opened for a woman in the LHW’s area');
      }
      final active = await (_db.select(_db.pregnancies)
            ..where((p) => p.womanId.equals(womanId) & p.status.equals('active') & p.deletedAt.isNull()))
          .getSingleOrNull();
      if (active != null) throw StateError('The woman already has an active pregnancy');
      await _writePregnancy(woman, input, by, _clock());
      return woman;
    });
  }

  Future<void> _writePregnancy(LocalWoman woman, PregnancyInput input, SessionUser by, DateTime now) async {
    final pregnancy = LocalPregnancy(
      id: _uuid.v4(),
      areaId: by.areaId,
      createdBy: by.id,
      createdOnDevice: now.toUtc(),
      womanId: woman.id,
      registeredOn: calendarDate(now),
      pregnancyMonthAtRegistration: input.pregnancyMonth,
      status: 'active',
      estimatedDeliveryDate: input.estimatedDeliveryDate == null ? null : calendarDate(input.estimatedDeliveryDate!),
      eddBasis: input.estimatedDeliveryDate == null ? null : input.eddBasis.code,
      lmpDate: input.lmpDate == null ? null : calendarDate(input.lmpDate!),
      reportedEdd: input.reportedEdd == null ? null : calendarDate(input.reportedEdd!),
    );
    await _db.into(_db.pregnancies).insert(pregnancy);
    await _db.enqueue(pregnancyPayload(pregnancy), queuedAt: now);

    final existing = await (_db.select(_db.obstetricHistory)
          ..where((h) => h.womanId.equals(woman.id) & h.deletedAt.isNull()))
        .getSingleOrNull();
    final history = LocalObstetricHistory(
      id: existing?.id ?? _uuid.v4(),
      areaId: by.areaId,
      createdBy: existing?.createdBy ?? by.id,
      createdOnDevice: existing?.createdOnDevice ?? now.toUtc(),
      serverSeq: existing?.serverSeq,
      version: existing?.version,
      conflictId: existing?.conflictId,
      womanId: woman.id,
      previousPregnancies: input.previousPregnancies,
      previousCSections: input.previousCSections,
      stillbirths: input.stillbirths,
      knownConditions: input.knownConditions,
    );
    if (existing == null) {
      await _db.into(_db.obstetricHistory).insert(history);
    } else {
      await _db.update(_db.obstetricHistory).replace(history);
    }
    await _db.enqueue(historyPayload(history), queuedAt: now);
  }

  /// Women already on this phone with the same name and husband's name (case
  /// and spaces ignored): a woman is registered only once (M2 FE-1), so the
  /// form warns before a second registration. The server also flags likely
  /// duplicates for the supervisor (M3 FE-2).
  Future<List<PatientSummary>> sameWoman({required String name, String? husbandName}) async {
    String norm(String? text) => (text ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final wanted = (norm(name), norm(husbandName));
    final all = await list();
    return [for (final p in all) if ((norm(p.woman.name), norm(p.woman.husbandName)) == wanted) p];
  }

  /// The women on this phone, sorted by village and then by name (M2 FE-3).
  /// [search] matches part of a name, patient ID, husband's name or village.
  /// With [near] (the LHW's position), they are sorted by the estimated
  /// distance to their home instead, nearest first; homes without GPS come last.
  Future<List<PatientSummary>> list({String search = '', ({double latitude, double longitude})? near}) async {
    final women = await (_db.select(_db.women)..where((w) => w.deletedAt.isNull())).get();
    final households = {for (final h in await _db.select(_db.households).get()) h.id: h};
    final pregnancies = await (_db.select(_db.pregnancies)..where((p) => p.deletedAt.isNull())).get();
    final statuses = await _syncStatuses('women');

    final query = search.trim().toLowerCase();
    final result = <PatientSummary>[];
    for (final woman in women) {
      final household = households[woman.householdId];
      if (query.isNotEmpty &&
          ![woman.name, woman.patientCode, woman.husbandName, household?.village]
              .any((text) => text != null && text.toLowerCase().contains(query))) {
        continue;
      }
      final lat = household?.latitude;
      final lon = household?.longitude;
      result.add(PatientSummary(
        woman: woman,
        household: household,
        pregnancy: _currentPregnancy(pregnancies.where((p) => p.womanId == woman.id)),
        syncStatus: statuses[woman.id] ?? SyncStatus.synced,
        distanceKm: near == null || lat == null || lon == null ? null : distanceKm(near.latitude, near.longitude, lat, lon),
      ));
    }
    int byVillageAndName(PatientSummary a, PatientSummary b) {
      // Women with no village recorded come last.
      final byVillage = _compareVillages(a.village, b.village);
      return byVillage != 0 ? byVillage : a.woman.name.toLowerCase().compareTo(b.woman.name.toLowerCase());
    }

    result.sort((a, b) {
      if (near == null) return byVillageAndName(a, b);
      final x = a.distanceKm;
      final y = b.distanceKm;
      if (x == null || y == null) return x == y ? byVillageAndName(a, b) : (x == null ? 1 : -1);
      final byDistance = x.compareTo(y);
      return byDistance != 0 ? byDistance : byVillageAndName(a, b);
    });
    return result;
  }

  /// One woman's file, or null if she is not on this phone.
  Future<PatientFile?> file(String womanId) async {
    final woman = await (_db.select(_db.women)..where((w) => w.id.equals(womanId))).getSingleOrNull();
    if (woman == null) return null;
    final household = await (_db.select(_db.households)..where((h) => h.id.equals(woman.householdId))).getSingleOrNull();
    final pregnancies =
        await (_db.select(_db.pregnancies)..where((p) => p.womanId.equals(womanId) & p.deletedAt.isNull())).get();
    final history = await (_db.select(_db.obstetricHistory)
          ..where((o) => o.womanId.equals(womanId) & o.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    final statuses = await _syncStatuses('women');
    return PatientFile(
      woman: woman,
      household: household,
      pregnancy: _currentPregnancy(pregnancies),
      history: history,
      syncStatus: statuses[womanId] ?? SyncStatus.synced,
    );
  }

  // The active pregnancy if there is one, otherwise the one the server numbered
  // last. Never chosen by device clock (LI-7).
  static LocalPregnancy? _currentPregnancy(Iterable<LocalPregnancy> pregnancies) {
    LocalPregnancy? best;
    for (final p in pregnancies) {
      if (best == null ||
          (p.status == 'active' && best.status != 'active') ||
          (p.status == best.status && (p.serverSeq ?? 1 << 62) > (best.serverSeq ?? 1 << 62))) {
        best = p;
      }
    }
    return best;
  }

  static int _compareVillages(String? a, String? b) {
    final x = (a ?? '').trim().toLowerCase();
    final y = (b ?? '').trim().toLowerCase();
    if (x.isEmpty || y.isEmpty) return x.isEmpty == y.isEmpty ? 0 : (x.isEmpty ? 1 : -1);
    return x.compareTo(y);
  }

  // Records of [table] still in the outbox (waiting, or refused by the server),
  // and those the server holds for the supervisor's review.
  Future<Map<String, SyncStatus>> _syncStatuses(String table) async {
    final entries = await (_db.select(_db.outbox)..where((o) => o.entityTable.equals(table))).get();
    final held = await (_db.select(_db.women)..where((w) => w.conflictId.isNotNull())).get();
    return {
      for (final w in held) w.id: SyncStatus.held,
      for (final e in entries) e.recordId: e.lastError == null ? SyncStatus.waiting : SyncStatus.refused,
    };
  }

  /// A calendar date as YYYY-MM-DD, as the server stores it.
  static String calendarDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Map<String, Object?> womanPayload(LocalWoman w) => syncPayload(
        table: 'women',
        id: w.id,
        areaId: w.areaId,
        createdOnDevice: w.createdOnDevice,
        deletedAt: w.deletedAt,
        data: {
          'householdId': w.householdId,
          'patientCode': w.patientCode,
          'name': w.name,
          'age': w.age,
          'husbandName': w.husbandName,
          'contactNumber': w.contactNumber,
        },
      );

  static Map<String, Object?> pregnancyPayload(LocalPregnancy p) => syncPayload(
        table: 'pregnancies',
        id: p.id,
        areaId: p.areaId,
        createdOnDevice: p.createdOnDevice,
        deletedAt: p.deletedAt,
        data: {
          'womanId': p.womanId,
          'registeredOn': p.registeredOn,
          'pregnancyMonthAtRegistration': p.pregnancyMonthAtRegistration,
          'status': p.status,
          'closedOn': p.closedOn,
          // Left out for a pregnancy saved before they existed: the server then
          // estimates the date from the month, as the app does.
          if (p.estimatedDeliveryDate != null) ...{
            'estimatedDeliveryDate': p.estimatedDeliveryDate,
            'eddBasis': p.eddBasis,
            'lmpDate': p.lmpDate,
            'reportedEdd': p.reportedEdd,
          },
        },
      );

  static Map<String, Object?> historyPayload(LocalObstetricHistory h) => syncPayload(
        table: 'obstetric_history',
        id: h.id,
        areaId: h.areaId,
        createdOnDevice: h.createdOnDevice,
        deletedAt: h.deletedAt,
        data: {
          'womanId': h.womanId,
          'previousPregnancies': h.previousPregnancies,
          'previousCSections': h.previousCSections,
          'stillbirths': h.stillbirths,
          'knownConditions': h.knownConditions,
        },
      );
}
