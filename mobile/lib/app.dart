import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'screens/widget_kit_screen.dart';
import 'theme/app_theme.dart';

/// The app always runs in Urdu. The Urdu locale makes Flutter lay out every
/// screen right to left. English strings exist for development and review.
class MediQoreApp extends StatelessWidget {
  const MediQoreApp({super.key, this.locale = urdu});

  static const Locale urdu = Locale('ur');

  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const WidgetKitScreen(),
    );
  }
}
