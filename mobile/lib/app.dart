import 'package:flutter/material.dart';

import 'app_services.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/inactivity_lock.dart';

/// The app runs in the language chosen in AppSettings: Urdu by default, or
/// English (M1 FE-4). The locale also sets the layout direction: Urdu right to
/// left, English left to right. Changing the language rebuilds every screen.
///
/// M1 FE-2: the login screen until someone signs in, then the home screen.
/// Locking (inactivity, the Lock button, sign-out or a deactivated account)
/// closes every open screen and returns to the login screen.
class MediQoreApp extends StatefulWidget {
  const MediQoreApp({super.key, required this.services});

  final AppServices services;

  @override
  State<MediQoreApp> createState() => _MediQoreAppState();
}

class _MediQoreAppState extends State<MediQoreApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late bool _wasUnlocked;

  @override
  void initState() {
    super.initState();
    _wasUnlocked = widget.services.session.isUnlocked;
    widget.services.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.services.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    final unlocked = widget.services.session.isUnlocked;
    if (_wasUnlocked && !unlocked) _navigator.currentState?.popUntil((route) => route.isFirst);
    _wasUnlocked = unlocked;
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final settings = services.settings;
    final session = services.session;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        navigatorKey: _navigator,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(urdu: settings.isUrdu),
        locale: settings.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => InactivityLock(session: session, child: child!),
        home: ListenableBuilder(
          listenable: session,
          builder: (context, _) =>
              session.isUnlocked ? HomeScreen(services: services) : LoginScreen(services: services),
        ),
      ),
    );
  }
}
