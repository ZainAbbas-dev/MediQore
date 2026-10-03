import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Bar that tells the LHW whether the phone is online and whether records are
/// still waiting to sync (scope Mockup 2: offline status indicator).
///
/// It only displays the state it is given; the sync engine (P0-6) supplies
/// [isOnline] and [pendingCount].
class OfflineStatusBar extends StatelessWidget {
  const OfflineStatusBar({super.key, required this.isOnline, this.pendingCount = 0});

  final bool isOnline;

  /// Records still in the outbox.
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (color, icon, message) = !isOnline
        ? (AppColors.statusOffline, Icons.cloud_off, l10n.statusOffline)
        : pendingCount > 0
            ? (AppColors.statusPending, Icons.cloud_upload, l10n.statusOnlinePending(pendingCount))
            : (AppColors.statusSynced, Icons.cloud_done, l10n.statusOnlineSynced);

    return Semantics(
      liveRegion: true,
      child: Material(
        color: color,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
