// M1 FE-4: switch the interface between Urdu and English.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The name of a language, written in its own script so a reader of either
/// language can find it: اردو in Nastaliq even while the app is in English.
Widget languageName(AppLocalizations l10n, Locale locale, {TextStyle? style}) => locale == AppSettings.urdu
    ? Text(
        l10n.languageNameUrdu,
        style: (style ?? const TextStyle()).copyWith(
          fontFamily: AppTheme.urduFontFamily,
          fontSize: (style?.fontSize ?? 16) + 4,
          height: AppTheme.urduLineHeight,
        ),
      )
    : Text(l10n.languageNameEnglish, style: (style ?? const TextStyle()).copyWith(fontFamily: AppTheme.latinFontFamily));

/// A compact button for the top of the sign-in screen: it shows the other
/// language and switches the whole app to it at once, saved on the phone.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key, required this.settings, this.color = Colors.white});

  final AppSettings settings;

  /// Text and border colour, white on the teal header.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final other = settings.isUrdu ? AppSettings.english : AppSettings.urdu;
        return Semantics(
          button: true,
          label: l10n.languageLabel,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              foregroundColor: color,
              backgroundColor: Colors.transparent,
              side: BorderSide(color: color.withValues(alpha: 0.7)),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.translate, size: 20),
            label: languageName(l10n, other, style: TextStyle(color: color, fontSize: 16)),
            onPressed: () => settings.setLocale(other),
          ),
        );
      },
    );
  }
}

/// The language choice in the settings: both languages, the current one ticked.
class LanguageChoice extends StatelessWidget {
  const LanguageChoice({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        children: [
          for (final (index, locale) in AppSettings.languages.indexed) ...[
            if (index > 0) const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: AppTheme.largeControlHeight,
              selected: settings.locale == locale,
              selectedColor: theme.colorScheme.primary,
              title: languageName(l10n, locale, style: const TextStyle(fontSize: 18, color: Colors.black87)),
              trailing: settings.locale == locale
                  ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                  : const Icon(Icons.circle_outlined, color: AppColors.border),
              onTap: () => settings.setLocale(locale),
            ),
          ],
        ],
      ),
    );
  }
}
