import '../data/patient_repository.dart';
import '../l10n/app_localizations.dart';

/// What the LHW reads about a record that has not reached the server, or null
/// once it has (M3 FE-2).
String? syncStatusText(AppLocalizations l10n, SyncStatus status) => switch (status) {
      SyncStatus.synced => null,
      SyncStatus.waiting => l10n.syncWaiting,
      SyncStatus.refused => l10n.syncRefused,
      SyncStatus.held => l10n.syncHeld,
    };
