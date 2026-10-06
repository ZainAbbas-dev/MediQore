import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/auth/session.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/screens/home_screen.dart';
import 'package:mediqore/screens/login_screen.dart';
import 'package:mediqore/screens/otp_screen.dart';
import 'package:mediqore/settings/app_settings.dart';

import '../helpers.dart';
import '../support/fake_sync_server.dart';

/// The whole app, from the login screen to the home screen and back (M1 FE-2,
/// FE-3), in Urdu.
void main() {
  final l10n = lookupAppLocalizations(AppSettings.urdu);
  late FakeSyncServer server;
  late AppServices services;

  setUp(() {
    server = FakeSyncServer();
    services = testServices(server);
  });
  tearDown(() => services.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    // Tall enough that every line of each screen is built and can be found.
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MediQoreApp(services: services));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  // Drift, the password key isolate and the fake HTTP client finish their work
  // outside the test's fake clock, so each action runs inside runAsync before
  // the screen is rebuilt.
  Future<void> tapAndWait(WidgetTester tester, String text) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(text));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  Future<void> signInOnScreen(WidgetTester tester, {String username = 'lhw.demo', String password = 'demo-password'}) async {
    await tester.enterText(find.byType(TextFormField).at(0), username);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tapAndWait(tester, l10n.signInButton);
  }

  testWidgets('a new phone signs in with its one-time code and opens the home screen', (tester) async {
    await pumpApp(tester);

    await signInOnScreen(tester);
    expect(find.byType(OtpScreen), findsOneWidget);
    final deviceId = services.settings.deviceId;
    expect(find.text(l10n.otpPhoneId(deviceId.substring(deviceId.length - 6))), findsOneWidget);

    // No code yet: the screen says so and stays open.
    await tester.enterText(find.byType(TextFormField), '123456');
    await tapAndWait(tester, l10n.otpVerifyButton);
    expect(find.text(l10n.otpNotIssued), findsOneWidget);

    server.issueCode(deviceId);
    await tester.enterText(find.byType(TextFormField), '482913');
    await tapAndWait(tester, l10n.otpVerifyButton);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OtpScreen), findsNothing);
    expect(find.text('Demo LHW'), findsOneWidget);
    expect(find.text(l10n.homeLhwCode('LHW-DEMO-001')), findsOneWidget);
    expect(find.text(l10n.homeArea('Demo Area 1')), findsOneWidget);
  });

  testWidgets('going back from the code screen returns to the login screen', (tester) async {
    await pumpApp(tester);
    await signInOnScreen(tester);

    await tapAndWait(tester, l10n.otpBackButton);

    expect(find.byType(OtpScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    // The password kept for the code step is forgotten.
    expect(await tester.runAsync(() => services.session.verifyCode('482913')), SignInResult.failed);
  });

  testWidgets('a wrong password is explained', (tester) async {
    await pumpApp(tester);

    await signInOnScreen(tester, password: 'wrong');

    expect(find.text(l10n.loginWrongPassword), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('the first sign-in on a phone without the internet is explained', (tester) async {
    server.offline = true;
    await pumpApp(tester);

    await signInOnScreen(tester);

    expect(find.text(l10n.loginNeedsInternet), findsOneWidget);
  });

  testWidgets('without the internet a known LHW signs in, and sync asks for an online sign-in', (tester) async {
    await tester.runAsync(() async {
      await signInApproved(services, server);
      services.session.lock(null);
    });
    server.offline = true;
    await pumpApp(tester);
    expect(tester.widget<TextFormField>(find.byType(TextFormField).at(0)).controller!.text, 'lhw.demo');

    await signInOnScreen(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text(l10n.homeOfflineSignIn), findsOneWidget);

    await tapAndWait(tester, l10n.syncNowButton);
    expect(find.text(l10n.homeSyncNeedsSignIn), findsOneWidget);

    await tapAndWait(tester, l10n.homeSignInAgainButton);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('locks itself after five minutes without a touch (M1 FE-2)', (tester) async {
    // Signed in before the app starts, so the lock timer runs on the test clock.
    await tester.runAsync(() => signInApproved(services, server));
    await pumpApp(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.pump(const Duration(minutes: 4));
    await tester.tap(find.text('Demo LHW')); // a touch restarts the timer
    await tester.pump(const Duration(minutes: 4));
    expect(services.session.isUnlocked, isTrue);

    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(services.session.isUnlocked, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text(l10n.loginLockedNotice), findsOneWidget);
  });

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip(l10n.homeSettingsSection));
    await tester.pumpAndSettle();
  }

  testWidgets('locking closes every open screen', (tester) async {
    await tester.runAsync(() => signInApproved(services, server));
    await pumpApp(tester);
    await openSettings(tester);
    await tapAndWait(tester, l10n.devHomeTitle);
    expect(find.byType(HomeScreen), findsNothing);

    services.session.lock();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('a deactivated account is locked out at the next sync (M1 FE-3)', (tester) async {
    await tester.runAsync(() => signInApproved(services, server));
    await pumpApp(tester);
    server.deactivated = true;

    await tapAndWait(tester, l10n.syncNowButton);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text(l10n.loginDeactivated), findsOneWidget);
  });

  testWidgets('the Lock and Sign out buttons return to the login screen', (tester) async {
    await tester.runAsync(() => signInApproved(services, server));
    await pumpApp(tester);

    await openSettings(tester);
    await tapAndWait(tester, l10n.homeLockButton);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text(l10n.loginLockedNotice), findsNothing);

    await signInOnScreen(tester);
    await openSettings(tester);
    await tapAndWait(tester, l10n.homeSignOutButton);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text(l10n.loginSignedOutNotice), findsOneWidget);
    expect(server.revokedRefreshTokens, hasLength(1));
  });
}
