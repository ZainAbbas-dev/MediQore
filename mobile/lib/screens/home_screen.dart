// M1 FE-2, FE-4: the first screen after sign-in (P0-7 screen 2). It shows who
// is signed in and the sync status, and opens registration and the patient
// list (M2). The gear icon opens the settings: language, Change PIN, lock and
// sign-out.
// M3 FE-2: records also sync on their own while online (AutoSync); the status
// bar follows.
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../auth/local_account.dart';
import '../l10n/app_localizations.dart';
import '../sync/auto_sync.dart';
import '../theme/app_colors.dart';
import '../widgets/app_cards.dart';
import '../widgets/large_button.dart';
import '../widgets/offline_status_bar.dart';
import 'patient_list_screen.dart';
import 'register_screen.dart';
import 'settings_screen.dart';
import 'sign_in_again_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _pending = 0;
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
    _refreshPending();
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
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    // After a lock the database is closed; the login screen replaces this one.
    final data = _services.session.data;
    if (data == null) return;
    final pending = await data.db.pendingCount();
    if (mounted) setState(() => _pending = pending);
  }

  // Opens a screen; the pending count may have changed when it closes.
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    await _refreshPending();
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
          if (outcome.errorCode == 'ACCOUNT_INACTIVE') return; // the session is locked; the login screen explains
          _message = l10n.syncFailed(outcome.errorCode ?? '');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refreshPending();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = _services.session;
    final user = session.user;
    if (user == null) return const SizedBox.shrink(); // locked; the app shows the login screen
    const gap = SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.homeSettingsSection,
            onPressed: () => _open(SettingsScreen(services: _services)),
          ),
        ],
      ),
      body: Column(
        children: [
          OfflineStatusBar(isOnline: _online, pendingCount: _pending),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProfileCard(user: user),
                if (session.lostUnsyncedRecords) ...[gap, NoticeCard(text: l10n.homeLostUnsynced, warning: true)],
                if (!session.canSync && !_needsSignIn) ...[gap, NoticeCard(text: l10n.homeSyncNeedsSignIn)],
                if (user.lhwCode != null) ...[
                  const SizedBox(height: 16),
                  // M2: registration and the patient list work without the internet.
                  _ActionCard(
                    icon: Icons.person_add,
                    title: l10n.homeRegisterButton,
                    subtitle: l10n.homeRegisterHint,
                    primary: true,
                    onTap: () => _open(RegisterScreen(services: _services)),
                  ),
                  gap,
                  // M3 FE-1: a visit starts from the woman's file.
                  _ActionCard(
                    icon: Icons.groups,
                    title: l10n.homePatientsButton,
                    subtitle: l10n.homeVisitHint,
                    onTap: () => _open(PatientListScreen(services: _services)),
                  ),
                ],
                const SizedBox(height: 16),
                SectionCard(
                  title: l10n.homeSyncSection,
                  icon: Icons.sync,
                  children: [
                    Text(l10n.homeSyncHint, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
                    if (_busy)
                      Row(
                        children: [
                          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(l10n.syncInProgress)),
                        ],
                      ),
                    if (_message != null) NoticeCard(text: _message!, icon: Icons.sync),
                    LargeButton(label: l10n.syncNowButton, icon: Icons.sync, secondary: true, onPressed: _busy ? null : () => _sync(l10n)),
                    if (_needsSignIn || !session.canSync)
                      LargeButton(
                        label: l10n.homeSignInAgainButton,
                        icon: Icons.login,
                        onPressed: () => _open(SignInAgainScreen(services: _services)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Who is signed in: name, LHW ID and area.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final SessionUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            InitialAvatar(user.fullName, radius: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  if (user.lhwCode != null) Text(l10n.homeLhwCode(user.lhwCode!), style: muted),
                  if (user.areaName != null) Text(l10n.homeArea(user.areaName!), style: muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A main task on the home screen: an icon, its name, a short explanation.
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap, this.primary = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// The most used task, in the app's colour.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = primary ? scheme.onPrimary : null;
    return Card(
      color: primary ? scheme.primary : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: primary ? Colors.white.withValues(alpha: 0.18) : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(icon, size: 30, color: primary ? scheme.onPrimary : scheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(color: foreground, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: primary ? scheme.onPrimary.withValues(alpha: 0.85) : AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: foreground ?? AppColors.mutedText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
