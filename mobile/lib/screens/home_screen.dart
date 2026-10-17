// M2, M3 FE-2: the home screen (final design screen 6). The teal header greets
// the LHW with her name, area and LHW ID and has the settings gear (language,
// Change PIN, lock, sign-out). The sync card over the header's edge shows the
// connection, the records waiting to be sent, when the phone last synced and
// Sync now; records also sync on their own while online (AutoSync) and in the
// background. Records the server refused are counted, and a reminder appears
// when records have waited a day without a sync (LI-8). Then today's work (a new
// registration, the registered women) and the recent visits with their sync
// state.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../app_services.dart';
import '../data/visit_repository.dart';
import '../l10n/app_localizations.dart';
import '../sync/auto_sync.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/curved_header.dart';
import '../widgets/large_button.dart';
import 'patient_file_screen.dart';
import 'patient_list_screen.dart';
import 'register_screen.dart';
import 'settings_screen.dart';
import 'sign_in_again_screen.dart';

/// "Today", "Yesterday" or the date of a visit, from the phone's clock (shown
/// to people only, never used to order records, LI-7).
String visitDay(BuildContext context, DateTime visitedAt, {DateTime? now}) {
  final l10n = AppLocalizations.of(context);
  final local = visitedAt.toLocal();
  final today = now ?? DateTime.now();
  final days = DateTime(today.year, today.month, today.day).difference(DateTime(local.year, local.month, local.day)).inDays;
  if (days == 0) return l10n.dayToday;
  if (days == 1) return l10n.dayYesterday;
  return DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).format(local);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// The daily sync reminder appears when records have waited this long (LI-8).
const Duration syncReminderAfter = Duration(days: 1);

/// "Today 10:31", "Yesterday 17:40" or a date, from the phone's clock.
String syncTime(BuildContext context, DateTime at, {DateTime? now}) {
  final time = DateFormat.Hm().format(at.toLocal());
  return '${visitDay(context, at, now: now)} \u2066$time\u2069';
}

class _HomeScreenState extends State<HomeScreen> {
  int _pending = 0;
  int _refused = 0;
  DateTime? _lastSync;
  int? _women;
  List<RecentVisit> _recent = const [];
  bool _online = false;
  bool _busy = false;
  String? _message;
  bool _needsSignIn = false;

  AppServices get _services => widget.services;

  @override
  void initState() {
    super.initState();
    _online = _services.autoSync.online ?? _services.session.canSync;
    _services.autoSync.addListener(_onAutoSync);
    _refresh();
  }

  @override
  void dispose() {
    _services.autoSync.removeListener(_onAutoSync);
    super.dispose();
  }

  // An automatic sync ran (M3 FE-2): show whether the server was reached and
  // what is still waiting.
  void _onAutoSync() {
    if (!mounted) return;
    final online = _services.autoSync.online;
    if (online != null) setState(() => _online = online);
    _refresh();
  }

  Future<void> _refresh() async {
    // After a lock the database is closed; the lock screen replaces this one.
    final data = _services.session.data;
    if (data == null) return;
    final pending = await data.db.pendingCount();
    final refused = await data.db.refusedCount();
    final lastSync = await data.db.lastSyncAt();
    final isLhw = _services.session.user?.lhwCode != null;
    final women = isLhw ? (await data.patients.list()).length : null;
    final recent = isLhw ? await data.visits.recent(limit: 5) : const <RecentVisit>[];
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _refused = refused;
      _lastSync = lastSync;
      _women = women;
      _recent = recent;
    });
  }

  // Opens a screen; the counts may have changed when it closes.
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    await _refresh();
  }

  Future<void> _sync(AppLocalizations l10n) async {
    setState(() {
      _busy = true;
      _message = null;
      _needsSignIn = false;
    });
    try {
      final outcome = await _services.autoSync.run();
      switch (outcome.problem) {
        case null:
          final report = outcome.report!;
          _message = [
            l10n.syncResult(report.pushed, report.pulled, report.rejected),
            if (report.held > 0) l10n.syncResultHeld(report.held),
          ].join('\n');
        case SyncProblem.needsSignIn:
          _needsSignIn = true;
          _message = l10n.homeSyncNeedsSignIn;
        case SyncProblem.offline:
          _message = l10n.homeSyncOffline;
        case SyncProblem.failed:
          if (outcome.errorCode == 'ACCOUNT_INACTIVE') return; // the app locks; the lock screen explains
          _message = l10n.syncFailed(outcome.errorCode ?? '');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = _services.session;
    final user = session.user;
    if (user == null) return const SizedBox.shrink(); // locked; the app shows the lock screen
    const gap = SizedBox(height: 12);
    final place = [?user.areaName, ?user.lhwCode].join(' · ');

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          CurvedHeader(
            title: l10n.appTitle,
            showBack: false,
            overlap: 44,
            actions: [
              HeaderIconButton(
                icon: const Icon(Icons.settings),
                tooltip: l10n.homeSettingsSection,
                onPressed: () => _open(SettingsScreen(services: _services)),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.homeGreeting, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                Text(
                  user.fullName,
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                if (place.isNotEmpty)
                  Text(place, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SyncCard(
                online: _online,
                pending: _pending,
                refused: _refused,
                lastSync: _lastSync == null ? l10n.homeNotSyncedYet : l10n.homeLastSync(syncTime(context, _lastSync!)),
                busy: _busy,
                onSync: _busy ? null : () => _sync(l10n),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_message != null) ...[NoticeCard(text: _message!, icon: Icons.sync), gap],
                if (_pending > 0 && (_lastSync == null || DateTime.now().difference(_lastSync!) >= syncReminderAfter)) ...[
                  NoticeCard(text: l10n.homeSyncReminder(_pending), tone: NoticeTone.attention),
                  gap,
                ],
                if (_refused > 0) ...[NoticeCard(text: l10n.homeRefused(_refused), icon: Icons.report_outlined, tone: NoticeTone.problem), gap],
                if (!session.canSync && !_needsSignIn) ...[NoticeCard(text: l10n.homeSyncNeedsSignIn), gap],
                if (_needsSignIn || !session.canSync) ...[
                  LargeButton(
                    label: l10n.homeSignInAgainButton,
                    icon: Icons.login,
                    onPressed: () => _open(SignInAgainScreen(services: _services)),
                  ),
                  gap,
                ],
                if (session.lostUnsyncedRecords) ...[NoticeCard(text: l10n.homeLostUnsynced, tone: NoticeTone.problem), gap],
                if (user.lhwCode != null) ...[
                  SectionHeading(l10n.homeTodayTasks),
                  // M2: registration and the patient list work without the internet.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _TaskCard(
                            icon: Icons.person_add_alt_1_outlined,
                            title: l10n.patientsNewButton,
                            subtitle: l10n.homeRegisterHint,
                            primary: true,
                            onTap: () => _open(RegisterScreen(services: _services)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TaskCard(
                            icon: Icons.groups_outlined,
                            title: l10n.homePatientsButton,
                            subtitle: _women == null ? '' : l10n.patientsCount(_women!),
                            onTap: () => _open(PatientListScreen(services: _services)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionHeading(l10n.homeRecentVisits),
                  if (_recent.isEmpty)
                    Card(child: EmptyNote(text: l10n.fileNoVisits, icon: Icons.event_note_outlined))
                  else
                    for (final recent in _recent) ...[
                      _RecentVisitCard(
                        recent: recent,
                        onTap: recent.woman == null
                            ? null
                            : () => _open(PatientFileScreen(services: _services, womanId: recent.woman!.id)),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The connection, the records waiting and Sync now, over the header's edge.
class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.online,
    required this.pending,
    required this.refused,
    required this.lastSync,
    required this.busy,
    required this.onSync,
  });

  final bool online;
  final int pending;

  /// Records the server refused; never "all sent" while there are any.
  final int refused;

  /// "Last synced: …" or "Not synced yet".
  final String lastSync;
  final bool busy;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (foreground, background, icon) = !online
        ? (AppColors.statusPending, AppColors.statusPendingBackground, Icons.cloud_upload_outlined)
        : pending > 0
        ? (AppColors.statusPending, AppColors.statusPendingBackground, Icons.cloud_upload_outlined)
        : refused > 0
        ? (AppColors.statusProblem, AppColors.statusProblemBackground, Icons.cloud_off_outlined)
        : (AppColors.statusSynced, AppColors.statusSyncedBackground, Icons.cloud_done_outlined);
    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // The state's colour and icon change smoothly after a sync.
                  AnimatedContainer(
                    duration: AppMotion.of(context, AppMotion.medium),
                    curve: AppMotion.standard,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
                    child: AnimatedSwitcher(
                      duration: AppMotion.of(context, AppMotion.medium),
                      child: Icon(icon, key: ValueKey(icon), color: foreground),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          online ? l10n.homeOnline : l10n.homeOffline,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          pending > 0
                              ? l10n.homeWaiting(pending)
                              : refused > 0
                              ? l10n.homeRefusedShort(refused)
                              : l10n.homeAllSent,
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
                        ),
                        Text(lastSync, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Under the text, full width: beside it the text had no room on a small phone.
              // Sync now and the spinner cross-fade in the same space, so the
              // card does not jump while it syncs.
              AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.short),
                child: busy
                    ? const SizedBox(
                        key: ValueKey('syncing'),
                        height: 48,
                        child: Center(
                          child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
                        ),
                      )
                    : FilledButton.tonalIcon(
                        key: const ValueKey('sync'),
                        onPressed: onSync,
                        style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                        icon: const Icon(Icons.sync),
                        label: Text(l10n.syncNowButton),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A main task: an icon in a circle, its name and a short line under it.
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.icon, required this.title, required this.subtitle, required this.onTap, this.primary = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// The most used task, in the app's colour.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = primary ? Colors.white : AppColors.text;
    return Card(
      color: primary ? AppColors.primary : AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: primary ? Colors.white.withValues(alpha: 0.18) : AppColors.primaryLight,
                child: Icon(icon, size: 28, color: primary ? Colors.white : AppColors.primaryDark),
              ),
              const SizedBox(height: 14),
              Text(title, style: theme.textTheme.titleMedium?.copyWith(color: foreground, fontWeight: FontWeight.w700)),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: primary ? Colors.white.withValues(alpha: 0.85) : AppColors.mutedText,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One recent visit: the woman, the day and BP, and the sync state.
class _RecentVisitCard extends StatelessWidget {
  const _RecentVisitCard({required this.recent, this.onTap});

  final RecentVisit recent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final visit = recent.summary.visit;
    final name = recent.woman?.name ?? '';
    final systolic = visit.systolicBpMmhg;
    final diastolic = visit.diastolicBpMmhg;
    final day = visitDay(context, visit.visitedAt);
    // The BP reads left to right inside the Urdu line.
    final line = systolic == null || diastolic == null ? day : l10n.visitLineBp(day, '\u2066$systolic/$diastolic\u2069');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              InitialAvatar(name, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text(line, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SyncStatusChip(recent.summary.syncStatus),
            ],
          ),
        ),
      ),
    );
  }
}
