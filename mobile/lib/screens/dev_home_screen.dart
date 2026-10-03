import 'package:flutter/material.dart';

import '../app_services.dart';
import '../l10n/app_localizations.dart';
import '../widgets/large_button.dart';
import 'sync_test_screen.dart';
import 'voice_check_screen.dart';
import 'widget_kit_screen.dart';

/// Temporary home screen for the Phase 0 checks (P0-2 widget kit, P0-6 sync,
/// P0-11 Urdu voice).
/// The login screen replaces it in Phase 1 (M1 FE-2).
class DevHomeScreen extends StatelessWidget {
  const DevHomeScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devHomeTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LargeButton(label: l10n.kitTitle, icon: Icons.widgets, onPressed: () => open(const WidgetKitScreen())),
          const SizedBox(height: 12),
          LargeButton(
            label: l10n.syncTestTitle,
            icon: Icons.sync,
            onPressed: () => open(SyncTestScreen(services: services)),
          ),
          const SizedBox(height: 12),
          LargeButton(
            label: l10n.voiceCheckTitle,
            icon: Icons.record_voice_over,
            onPressed: () => open(const VoiceCheckScreen()),
          ),
        ],
      ),
    );
  }
}
