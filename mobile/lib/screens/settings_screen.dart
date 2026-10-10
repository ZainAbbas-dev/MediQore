// M3 FE-3, M1 FE-2: the app's settings (final design screen 7), opened from
// the gear icon on the home screen: the language (اردو / English, saved on the
// phone), the account with Change PIN, Lock the app and Sign out, and the
// Phase 0 checks in development and test builds.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../build_flags.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_cards.dart';
import '../widgets/language_switch.dart';
import '../widgets/large_button.dart';
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
    final session = services.session;
    final user = session.user;
    if (user == null) return const SizedBox.shrink(); // locked; the app shows the lock screen
    const gap = SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeSettingsSection)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: l10n.languageLabel,
            icon: Icons.translate,
            children: [LanguageChoice(settings: services.settings)],
          ),
          gap,
          SectionCard(
            title: l10n.settingsAccountSection,
            icon: Icons.person,
            children: [
              InfoRow(l10n.settingsName, user.fullName),
              if (user.lhwCode != null) InfoRow(l10n.loginUsername, user.lhwCode, ltr: true),
              if (user.areaName != null) InfoRow(l10n.settingsArea, user.areaName),
              const SizedBox(height: 4),
              LargeButton(
                label: l10n.pinChangeTitle,
                icon: Icons.pin,
                secondary: true,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PinCreateScreen(services: services, mode: PinCreateMode.change),
                  ),
                ),
              ),
              LargeButton(label: l10n.homeLockButton, icon: Icons.lock, secondary: true, onPressed: () => session.lock(null)),
              LargeButton(
                label: l10n.homeSignOutButton,
                icon: Icons.logout,
                secondary: true,
                onPressed: () => _signOut(context),
              ),
            ],
          ),
          if (kDebugMode || testBuild) ...[
            gap,
            SectionCard(
              title: l10n.settingsTestingSection,
              icon: Icons.build,
              children: [
                InfoRow(l10n.loginServerLabel, services.serverAddress, ltr: true),
                LargeButton(
                  label: l10n.devHomeTitle,
                  icon: Icons.checklist,
                  secondary: true,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DevHomeScreen(services: services))),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
