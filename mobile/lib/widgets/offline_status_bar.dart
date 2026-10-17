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
  const OfflineStatusBar({super.key, required this.isOnline, this.pendingCount = 0, this.compact = false});

  final bool isOnline;

  /// Records still in the outbox.
  final int pendingCount;

  /// A small white chip for the teal header of a data entry screen (final
  /// design 15: the offline chip in the header), with the full message for
  /// screen readers.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (foreground, background, icon, message) = !isOnline
        ? (AppColors.statusOffline, AppColors.statusOfflineBackground, Icons.cloud_off, l10n.statusOffline)
        : pendingCount > 0
        ? (AppColors.statusPending, AppColors.statusPendingBackground, Icons.cloud_upload, l10n.statusOnlinePending(pendingCount))
        : (AppColors.statusSynced, AppColors.statusSyncedBackground, Icons.cloud_done, l10n.statusOnlineSynced);

    if (compact) {
      final short = !isOnline
          ? l10n.statusChipOffline
          : pendingCount > 0
          ? l10n.statusChipPending(pendingCount)
          : l10n.statusChipSynced;
      return Semantics(
        liveRegion: true,
        label: message,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground, size: 18),
                const SizedBox(width: 6),
                Text(
                  short,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: foreground, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }
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
  const LiveStatusBar({super.key, required this.services, this.compact = false});

  final AppServices services;

  /// See [OfflineStatusBar.compact].
  final bool compact;

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
          OfflineStatusBar(
            isOnline: services.autoSync.online ?? services.session.canSync,
            pendingCount: _pending,
            compact: widget.compact,
          ),
    );
  }
}
