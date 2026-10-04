// M2 FE-1, FE-2, FE-3: registering a pregnant woman, offline. One registration
// writes the household (or reuses one), the woman, her pregnancy file and her
// obstetric history, each with its outbox entry, in a single transaction.
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../auth/local_account.dart';
import 'app_database.dart';
import 'household_repository.dart';

/// What the registration form collects (M2 FE-1, FE-2, FE-3).
class RegistrationInput {
  const RegistrationInput({
    required this.name,
    required this.age,
    this.husbandName,
    this.contactNumber,
    required this.pregnancyMonth,
    this.householdId,
    this.village,
    this.address,
    this.latitude,
    this.longitude,
    this.previousPregnancies = 0,
    this.previousCSections = 0,
    this.stillbirths = 0,
    this.knownConditions,
  });

  final String name;
  final int age;
  final String? husbandName;
  final String? contactNumber;
  final int pregnancyMonth;

  /// The home of an already registered woman, for a second woman in the same
  /// household. When null, a new household is made from [village], [address]
  /// and the GPS position.
  final String? householdId;
  final String? village;
  final String? address;
  final double? latitude;
  final double? longitude;

  final int previousPregnancies;
  final int previousCSections;
  final int stillbirths;
  final String? knownConditions;
}

/// Whether a record has reached the server.
enum SyncStatus { synced, waiting, refused }

/// One line of the patient list.
class PatientSummary {
  const PatientSummary({required this.woman, this.household, this.pregnancy, required this.syncStatus});

  final LocalWoman woman;
  final LocalHousehold? household;

  /// The active pregnancy, or the latest one.
  final LocalPregnancy? pregnancy;
  final SyncStatus syncStatus;

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

class PatientRepository {
  PatientRepository(this._db, {this._uuid = const Uuid(), DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// Saves a registration made by [by], an LHW, and returns the woman with
  /// her new patient ID: the LHW code plus this phone's counter (M2 FE-1).
  Future<LocalWoman> register(RegistrationInput input, {required SessionUser by}) async {
    final lhwCode = by.lhwCode;
    if (lhwCode == null) throw StateError('Only an LHW can register a woman');
    final now = _clock();
    final createdOnDevice = now.toUtc();

    return _db.transaction(() async {
      var householdId = input.householdId;
      if (householdId == null) {
        final household = LocalHousehold(
          id: _uuid.v4(),
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
      }

      final number = await _db.takePatientNumber(lhwCode);
      final woman = LocalWoman(
        id: _uuid.v4(),
        areaId: by.areaId,
        createdBy: by.id,
        createdOnDevice: createdOnDevice,
        householdId: householdId,
        patientCode: '$lhwCode-${number.toString().padLeft(4, '0')}',
        name: input.name,
        age: input.age,
        husbandName: input.husbandName,
        contactNumber: input.contactNumber,
      );
      await _db.into(_db.women).insert(woman);
      await _db.enqueue(womanPayload(woman), queuedAt: now);

      final pregnancy = LocalPregnancy(
        id: _uuid.v4(),
        areaId: by.areaId,
        createdBy: by.id,
        createdOnDevice: createdOnDevice,
        womanId: woman.id,
        registeredOn: calendarDate(now),
        pregnancyMonthAtRegistration: input.pregnancyMonth,
        status: 'active',
      );
      await _db.into(_db.pregnancies).insert(pregnancy);
      await _db.enqueue(pregnancyPayload(pregnancy), queuedAt: now);

      final history = LocalObstetricHistory(
        id: _uuid.v4(),
        areaId: by.areaId,
        createdBy: by.id,
        createdOnDevice: createdOnDevice,
        womanId: woman.id,
        previousPregnancies: input.previousPregnancies,
        previousCSections: input.previousCSections,
        stillbirths: input.stillbirths,
        knownConditions: input.knownConditions,
      );
      await _db.into(_db.obstetricHistory).insert(history);
      await _db.enqueue(historyPayload(history), queuedAt: now);

      return woman;
    });
  }

  /// The women on this phone, sorted by village and then by name (M2 FE-3).
  /// [search] matches part of a name, patient ID, husband's name or village.
  Future<List<PatientSummary>> list({String search = ''}) async {
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
      result.add(PatientSummary(
        woman: woman,
        household: household,
        pregnancy: _currentPregnancy(pregnancies.where((p) => p.womanId == woman.id)),
        syncStatus: statuses[woman.id] ?? SyncStatus.synced,
      ));
    }
    result.sort((a, b) {
      // Women with no village recorded come last.
      final byVillage = _compareVillages(a.village, b.village);
      return byVillage != 0 ? byVillage : a.woman.name.toLowerCase().compareTo(b.woman.name.toLowerCase());
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

  // Records of [table] still in the outbox: waiting, or refused by the server.
  Future<Map<String, SyncStatus>> _syncStatuses(String table) async {
    final entries = await (_db.select(_db.outbox)..where((o) => o.entityTable.equals(table))).get();
    return {for (final e in entries) e.recordId: e.lastError == null ? SyncStatus.waiting : SyncStatus.refused};
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
