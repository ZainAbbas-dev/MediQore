// M1 FE-4: switch the interface between Urdu and English.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../theme/app_theme.dart';

/// Two large buttons, اردو and English, each written in its own script so a
/// reader of either language can find it. Choosing one switches the whole app
/// at once and saves the choice on the phone.
class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.languageLabel, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            style: SegmentedButton.styleFrom(minimumSize: const Size.fromHeight(AppTheme.largeControlHeight)),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: AppSettings.urdu.languageCode,
                // Urdu stays in Nastaliq even while the app is in English.
                label: Text(
                  l10n.languageNameUrdu,
                  style: const TextStyle(
                    fontFamily: AppTheme.urduFontFamily,
                    fontSize: 22,
                    height: AppTheme.urduLineHeight,
                  ),
                ),
              ),
              ButtonSegment(
                value: AppSettings.english.languageCode,
                label: Text(l10n.languageNameEnglish, style: const TextStyle(fontSize: 18)),
              ),
            ],
            selected: {settings.locale.languageCode},
            onSelectionChanged: (selected) => settings.setLocale(Locale(selected.single)),
          ),
        ],
      ),
    );
  }
}
