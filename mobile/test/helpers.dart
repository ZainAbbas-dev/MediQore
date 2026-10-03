import 'package:flutter/material.dart';
import 'package:mediqore/app.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/theme/app_theme.dart';

/// Wraps [child] in the app's theme and localisation (Urdu by default), so a
/// widget can be tested on its own.
Widget wrapInApp(Widget child, {Locale locale = MediQoreApp.urdu}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [child])),
  );
}
