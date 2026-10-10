import 'package:flutter/material.dart';

import '../app_services.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Strip under the app bar that tells the LHW whether the phone is online and
/// whether records are still waiting to sync (scope Mockup 2: offline status
/// indicator). Offline is normal in the field, so it is calm, not alarming.
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
    final (foreground, background, icon, message) = !isOnline
        ? (AppColors.statusOffline, AppColors.statusOfflineBackground, Icons.cloud_off, l10n.statusOffline)
        : pendingCount > 0
        ? (AppColors.statusPending, AppColors.statusPendingBackground, Icons.cloud_upload, l10n.statusOnlinePending(pendingCount))
        : (AppColors.statusSynced, AppColors.statusSyncedBackground, Icons.cloud_done, l10n.statusOnlineSynced);

    return Semantics(
      liveRegion: true,
      child: Material(
        color: background,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The [OfflineStatusBar] of a data entry screen: it follows the automatic sync
/// (M3 FE-2) and counts the records waiting on the phone when it opens and
/// after each sync.
class LiveStatusBar extends StatefulWidget {
  const LiveStatusBar({super.key, required this.services});

  final AppServices services;

  @override
  State<LiveStatusBar> createState() => _LiveStatusBarState();
}

class _LiveStatusBarState extends State<LiveStatusBar> {
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    widget.services.autoSync.addListener(_count);
    _count();
  }

  @override
  void dispose() {
    widget.services.autoSync.removeListener(_count);
    super.dispose();
  }

  Future<void> _count() async {
    final data = widget.services.session.data; // closed after a lock
    if (data == null) return;
    final pending = await data.db.pendingCount();
    if (mounted) setState(() => _pending = pending);
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return ListenableBuilder(
      listenable: services.autoSync,
      builder: (context, _) =>
          OfflineStatusBar(isOnline: services.autoSync.online ?? services.session.canSync, pendingCount: _pending),
    );
  }
}
