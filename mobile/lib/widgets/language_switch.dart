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

/// The language choice in the settings (final design screen 7): both
/// languages side by side, each in its own script, the current one filled.
class LanguageChoice extends StatelessWidget {
  const LanguageChoice({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppTheme.radius)),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              for (final (index, locale) in AppSettings.languages.indexed) ...[
                if (index > 0) const SizedBox(width: 6),
                Expanded(child: _LanguageOption(l10n: l10n, locale: locale, selected: settings.locale == locale, settings: settings)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.l10n, required this.locale, required this.selected, required this.settings});

  final AppLocalizations l10n;
  final Locale locale;
  final bool selected;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.text;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => settings.setLocale(locale),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[Icon(Icons.check, size: 20, color: color), const SizedBox(width: 6)],
                  Flexible(
                    child: languageName(l10n, locale, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
