import 'package:flutter/material.dart';

import 'app_services.dart';
import 'auth/session.dart';
import 'l10n/app_localizations.dart';
import 'screens/activation_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/pin_create_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/inactivity_lock.dart';

/// The app runs in the language chosen in AppSettings: Urdu by default, or
/// English (M1 FE-4). The locale also sets the layout direction: Urdu right to
/// left, English left to right. Changing the language rebuilds every screen.
///
/// M1 FE-2: activation until the phone is activated, then the PIN screen, then
/// the lock screen whenever the app is locked and the home screen while it is
/// open. Every change of stage (unlock, lock by inactivity or the Lock button,
/// sign-out, a deactivated account) closes the screens opened on top.
class MediQoreApp extends StatefulWidget {
  const MediQoreApp({super.key, required this.services});

  final AppServices services;

  @override
  State<MediQoreApp> createState() => _MediQoreAppState();
}

class _MediQoreAppState extends State<MediQoreApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late SessionStage _stage;

  @override
  void initState() {
    super.initState();
    _stage = widget.services.session.stage;
    widget.services.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.services.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    final stage = widget.services.session.stage;
    if (stage != _stage) _navigator.currentState?.popUntil((route) => route.isFirst);
    _stage = stage;
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
          builder: (context, _) => switch (session.stage) {
            SessionStage.activation => ActivationScreen(services: services),
            SessionStage.createPin => PinCreateScreen(services: services, mode: PinCreateMode.activation),
            SessionStage.locked => LockScreen(services: services),
            SessionStage.unlocked => HomeScreen(services: services),
          },
        ),
      ),
    );
  }
}
