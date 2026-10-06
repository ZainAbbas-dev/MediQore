// M1 FE-4, M3 FE-3, M1 FE-2: the app's settings, opened from the gear icon on
// the home screen: the language, voice guidance with a button to test the
// voice, the signed-in account with Lock and Sign out, and the Phase 0 checks
// in development and test builds.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../build_flags.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_cards.dart';
import '../widgets/language_switch.dart';
import '../widgets/large_button.dart';
import '../widgets/voice_setting.dart';
import 'dev_home_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = services.session;
    final user = session.user;
    if (user == null) return const SizedBox.shrink(); // locked; the app shows the login screen
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
          // Voice guidance is for data entry, which LHWs do (M3 FE-3).
          if (user.lhwCode != null) ...[
            gap,
            SectionCard(
              title: l10n.settingsVoiceSection,
              icon: Icons.record_voice_over,
              children: [VoiceSetting(guidance: services.voice)],
            ),
          ],
          gap,
          SectionCard(
            title: l10n.settingsAccountSection,
            icon: Icons.person,
            children: [
              InfoRow(l10n.settingsName, user.fullName),
              if (user.lhwCode != null) InfoRow(l10n.loginUsername, user.lhwCode, ltr: true),
              if (user.areaName != null) InfoRow(l10n.settingsArea, user.areaName),
              const SizedBox(height: 4),
              LargeButton(label: l10n.homeLockButton, icon: Icons.lock, secondary: true, onPressed: () => session.lock(null)),
              LargeButton(label: l10n.homeSignOutButton, icon: Icons.logout, secondary: true, onPressed: session.signOut),
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
