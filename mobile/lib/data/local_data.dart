// M3 FE-2: everything that reads or writes the encrypted database. It exists
// only while the app is unlocked: Session opens it with the password key at
// sign-in and closes it when the app locks.
import '../sync/sync_api.dart';
import '../sync/sync_service.dart';
import 'app_database.dart';
import 'household_repository.dart';
import 'patient_repository.dart';

class LocalData {
  LocalData(this.db, {required SyncApi api, required String deviceId})
      : households = HouseholdRepository(db),
        patients = PatientRepository(db),
        sync = SyncService(db: db, api: api, deviceId: deviceId);

  final AppDatabase db;
  final HouseholdRepository households;

  /// Registered women and their pregnancy files (M2).
  final PatientRepository patients;
  final SyncService sync;
}
