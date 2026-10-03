import 'data/app_database.dart';
import 'data/household_repository.dart';
import 'sync/sync_api.dart';
import 'sync/sync_service.dart';

/// The app's long-lived objects, created once in main() and handed to the
/// screens that need them. Tests pass an in-memory database and a fake API.
class AppServices {
  AppServices({required this.db, required this.api})
      : households = HouseholdRepository(db),
        sync = SyncService(db: db, api: api);

  factory AppServices.onDevice() => AppServices(db: AppDatabase.onDevice(), api: SyncApi());

  final AppDatabase db;
  final SyncApi api;
  final HouseholdRepository households;
  final SyncService sync;
}
