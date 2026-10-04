import 'data/app_database.dart';
import 'data/household_repository.dart';
import 'settings/app_settings.dart';
import 'sync/sync_api.dart';
import 'sync/sync_service.dart';

/// The app's long-lived objects, created once in main() and handed to the
/// screens that need them. Tests pass an in-memory database, a fake API and,
/// by default, settings that start in Urdu and are not saved.
class AppServices {
  AppServices({required this.db, required this.api, AppSettings? settings})
      : settings = settings ?? AppSettings(),
        households = HouseholdRepository(db),
        sync = SyncService(db: db, api: api);

  /// Real services on the phone. [settings] come from [AppSettings.load].
  factory AppServices.onDevice({required AppSettings settings}) =>
      AppServices(db: AppDatabase.onDevice(), api: SyncApi(), settings: settings);

  final AppDatabase db;
  final SyncApi api;
  final AppSettings settings;
  final HouseholdRepository households;
  final SyncService sync;
}
