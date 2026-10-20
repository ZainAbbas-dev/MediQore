// M3 FE-3, M1 FE-2: the app's settings (final design screen 7), opened from
// the gear icon on the home screen: the language row and its sheet (اردو /
// English, saved on the phone), the account with Change PIN, Lock the app and Sign out, and the
// Phase 0 checks in development and test builds.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../build_flags.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/curved_header.dart';
import '../widgets/language_switch.dart';
import 'dev_home_screen.dart';
import 'pin_create_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.services});

  final AppServices services;

  // Sign-out removes the records and the account from the phone, so it asks
  // first, and is refused while records are waiting to be sent.
  Future<void> _signOut(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final waiting = await services.session.data?.db.pendingCount() ?? 0;
    if (waiting > 0) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.signOutBlocked(waiting))));
      return;
    }
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signOutConfirmTitle),
        content: Text(l10n.signOutConfirmText),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.homeSignOutButton)),
        ],
      ),
    );
    if (confirmed != true) return;
    final done = await services.session.signOut();
    if (!done) messenger.showSnackBar(SnackBar(content: Text(l10n.signOutBlocked(await _waiting()))));
  }

  Future<int> _waiting() async => await services.session.data?.db.pendingCount() ?? 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = services.session;
    final user = session.user;
    if (user == null) return const SizedBox.shrink(); // locked; the app shows the lock screen
    const gap = SizedBox(height: 20);
    final place = [?user.lhwCode, ?user.areaName].join(' · ');

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          CurvedHeader(title: l10n.homeSettingsSection, overlap: _profileOverlap),
          Transform.translate(
            offset: const Offset(0, -_profileOverlap),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          InitialAvatar(user.fullName, radius: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.fullName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                                if (place.isNotEmpty)
                                  Text(place, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(clipBehavior: Clip.antiAlias, child: LanguageSettingTile(settings: services.settings)),
                  gap,
                  SectionHeading(l10n.settingsAccountSection),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _ActionTile(
                          icon: Icons.pin_outlined,
                          label: l10n.pinChangeTitle,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PinCreateScreen(services: services, mode: PinCreateMode.change),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        _ActionTile(icon: Icons.lock_outline, label: l10n.homeLockButton, onTap: () => session.lock(null)),
                        const Divider(height: 1),
                        _ActionTile(
                          icon: Icons.logout,
                          label: l10n.homeSignOutButton,
                          danger: true,
                          onTap: () => _signOut(context),
                        ),
                      ],
                    ),
                  ),
                  if (kDebugMode || testBuild) ...[
                    gap,
                    SectionHeading(l10n.settingsTestingSection),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: InfoRow(l10n.loginServerLabel, services.serverAddress, ltr: true),
                          ),
                          const Divider(height: 1),
                          _ActionTile(
                            icon: Icons.checklist,
                            label: l10n.devHomeTitle,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => DevHomeScreen(services: services)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// How far the profile card reaches over the header.
  static const double _profileOverlap = 40;
}

/// One action in a settings card: an icon in a soft circle, the label and an
/// arrow. [danger] shows it in red (sign out).
class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.statusProblem : AppColors.primaryDark;
    return ListTile(
      minTileHeight: AppTheme.largeControlHeight + 4,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: danger ? AppColors.statusProblemBackground : AppColors.primarySoft,
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: danger ? color : AppColors.text),
      ),
      trailing: Icon(Icons.chevron_right, size: 22, color: AppColors.mutedText),
      onTap: onTap,
    );
  }
}
