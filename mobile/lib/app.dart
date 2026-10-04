import 'package:flutter/material.dart';

import 'app_services.dart';
import 'l10n/app_localizations.dart';
import 'screens/dev_home_screen.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';

/// The app runs in the language chosen in [AppSettings]: Urdu by default,
/// or English (M1 FE-4). The locale also sets the layout direction: Urdu right
/// to left, English left to right. Changing the language rebuilds every screen.
class MediQoreApp extends StatelessWidget {
  const MediQoreApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(urdu: settings.isUrdu),
        locale: settings.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: DevHomeScreen(services: services),
      ),
    );
  }
}
