// M3 FE-3: switch the interface between Urdu and English.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
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

/// [style] for a few Urdu words beside Latin text, set in Nastaliq and a
/// quarter larger, because Nastaliq looks smaller than Latin at the same size.
TextStyle? _besideLatin(TextStyle? style, {required bool urdu}) => urdu
    ? style?.copyWith(fontFamily: AppTheme.urduFontFamily, fontSize: (style.fontSize ?? 14) * 1.25)
    : style;

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

/// The language row in the settings: "زبان · Language" (the word in the
/// other language smaller, so either reader can find it), the current
/// language in its own script and an arrow. A tap opens [showLanguageSheet].
class LanguageSettingTile extends StatelessWidget {
  const LanguageSettingTile({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // The word in the other language stays smaller than the row's own word.
    TextStyle? aside() =>
        (settings.isUrdu ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)?.copyWith(color: AppColors.mutedText);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => ListTile(
        minTileHeight: AppTheme.largeControlHeight + 4,
        leading: const CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primarySoft,
          child: Icon(Icons.translate, color: AppColors.primaryDark, size: 22),
        ),
        title: Text.rich(
          TextSpan(
            text: l10n.languageLabel,
            style: theme.textTheme.titleMedium?.copyWith(color: AppColors.text),
            children: [
              TextSpan(text: ' · ', style: aside()),
              TextSpan(text: l10n.languageLabelOther, style: _besideLatin(aside(), urdu: !settings.isUrdu)),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            languageName(l10n, settings.locale, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.mutedText)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 22, color: AppColors.mutedText),
          ],
        ),
        onTap: () => showLanguageSheet(context, settings),
      ),
    );
  }
}

/// The language sheet: both languages as large rows, each named in both
/// scripts, and **Save**. The app switches only on Save, after the sheet
/// closes; the choice is kept on the phone.
Future<void> showLanguageSheet(BuildContext context, AppSettings settings) async {
  final chosen = await showModalBottomSheet<Locale>(
    context: context,
    sheetAnimationStyle: AppMotion.sheet,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _LanguageSheet(current: settings.locale),
  );
  if (chosen != null) await settings.setLocale(chosen);
}

class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet({required this.current});

  final Locale current;

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  late Locale _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final urdu = Localizations.localeOf(context) == AppSettings.urdu;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.languageSheetTitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text(
            l10n.languageSheetSubtitle,
            style: _besideLatin(theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText), urdu: !urdu),
          ),
          const SizedBox(height: 20),
          for (final locale in AppSettings.languages) ...[
            _LanguageOption(
              name: languageName(
                l10n,
                locale,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.text),
              ),
              otherName: locale == AppSettings.urdu ? l10n.languageNameUrduLatin : l10n.languageNameEnglishUrdu,
              otherNameIsUrdu: locale == AppSettings.english,
              selected: _selected == locale,
              onTap: () => setState(() => _selected = locale),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          FilledButton(onPressed: () => Navigator.of(context).pop(_selected), child: Text(l10n.languageSaveButton)),
        ],
      ),
    );
  }
}

/// One language in the sheet, 76 dp tall: a radio, the name in its own script
/// and in the other one, and a tick. The chosen one has a teal border and a
/// light teal fill.
class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.name,
    required this.otherName,
    required this.otherNameIsUrdu,
    required this.selected,
    required this.onTap,
  });

  final Widget name;
  final String otherName;
  final bool otherNameIsUrdu;
  final bool selected;
  final VoidCallback onTap;

  static const _corners = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.short),
        curve: AppMotion.enter,
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: _corners,
          border: Border.all(color: selected ? AppColors.primary : AppColors.fieldBorder, width: selected ? 2 : 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: _corners,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 76),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? AppColors.primary : AppColors.mutedText,
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          name,
                          Text(' / ', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.mutedText)),
                          Text(
                            otherName,
                            style: _besideLatin(
                              theme.textTheme.titleMedium?.copyWith(color: AppColors.mutedText),
                              urdu: otherNameIsUrdu,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected) const Icon(Icons.check, color: AppColors.primary, size: 26),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
