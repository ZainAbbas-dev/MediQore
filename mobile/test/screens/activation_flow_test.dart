import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/auth/session.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/screens/activation_screen.dart';
import 'package:mediqore/screens/home_screen.dart';
import 'package:mediqore/screens/lock_screen.dart';
import 'package:mediqore/screens/pin_create_screen.dart';
import 'package:mediqore/screens/pin_reset_screen.dart';
import 'package:mediqore/screens/sign_in_again_screen.dart';
import 'package:mediqore/settings/app_settings.dart';

import '../helpers.dart';
import '../support/fake_dialer.dart';
import '../support/fake_sync_server.dart';

/// The whole app through activation, the PIN, the lock screen, PIN reset and
/// sign-out (M1 FE-2, FE-3), in Urdu.
void main() {
  final l10n = lookupAppLocalizations(AppSettings.urdu);
  late FakeSyncServer server;
  late FakeDialer dialer;
  late AppServices services;
  late DateTime now;

  setUp(() {
    server = FakeSyncServer();
    dialer = FakeDialer();
    now = DateTime.utc(2026, 10, 10, 9);
    services = testServices(server, null, null, null, dialer, () => now);
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

  // Drift, the PIN hash isolate and the fake HTTP client finish their work
  // outside the test's fake clock, so each action runs inside runAsync before
  // the screen is rebuilt.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  Future<void> typePin(WidgetTester tester, String pin) async {
    await tester.runAsync(() async {
      for (final digit in pin.split('')) {
        await tester.tap(find.widgetWithText(TextButton, digit));
        await tester.pump();
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  Future<void> activateOnScreen(WidgetTester tester, {String password = 'demo-password', String? code}) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'lhw.demo');
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.enterText(find.byType(TextFormField).at(2), code ?? 'K7QM-4R2X');
    await tapAndWait(tester, find.text(l10n.activateButton));
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip(l10n.homeSettingsSection));
    await tester.pumpAndSettle();
  }

  Future<void> lockApp(WidgetTester tester) async {
    services.session.lock(null);
    await tester.runAsync(() => services.session.closed);
    await tester.pumpAndSettle();
  }

  testWidgets('a new phone is activated with its code, gets a PIN and opens the home screen', (tester) async {
    server.addFromAnotherDevice('3f2b6c1a-5d4e-4f7a-9b8c-0d1e2f3a4b5c', 'Dhok Syedan');
    await pumpApp(tester);
    expect(find.text(l10n.activateNote), findsOneWidget);

    await activateOnScreen(tester);
    expect(find.text(l10n.activateCodeInvalid), findsOneWidget, reason: 'no code issued yet');

    server.issueActivationCode();
    await activateOnScreen(tester, code: 'k7qm4r2x');
    expect(find.byType(PinCreateScreen), findsOneWidget);
    expect(find.text(l10n.pinStepEnter), findsOneWidget);

    await typePin(tester, '246810');
    expect(find.text(l10n.pinStepRepeat), findsOneWidget);
    await typePin(tester, '246811');
    expect(find.text(l10n.pinMismatch), findsOneWidget);
    expect(find.text(l10n.pinStepEnter), findsOneWidget);

    await typePin(tester, '246810');
    await typePin(tester, '246810');
    await settle(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Demo LHW'), findsOneWidget);
    expect(find.text(l10n.homeLhwCode('LHW-DEMO-001')), findsOneWidget);
  });

  testWidgets('a wrong password and a missing connection are explained', (tester) async {
    server.issueActivationCode();
    await pumpApp(tester);

    await activateOnScreen(tester, password: 'wrong');
    expect(find.text(l10n.loginWrongPassword), findsOneWidget);

    server.offline = true;
    await activateOnScreen(tester);
    expect(find.text(l10n.loginNeedsInternet), findsOneWidget);
    expect(find.byType(PinCreateScreen), findsNothing);
  });

  group('on an activated phone', () {
    setUp(() async {
      await activateApp(services, server);
    });

    testWidgets('the lock screen opens the app with the PIN, offline', (tester) async {
      await pumpApp(tester);
      await lockApp(tester);
      server.offline = true;

      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.text(l10n.lockGreeting('Demo')), findsOneWidget);
      await typePin(tester, testPin);

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a wrong PIN disables the keypad with a countdown; Forgot PIN and the emergency call still work', (tester) async {
      await pumpApp(tester);
      await lockApp(tester);

      // Typed on the test clock, so the countdown timer runs on it too.
      for (final digit in '000000'.split('')) {
        await tester.tap(find.widgetWithText(TextButton, digit));
        await tester.pump();
      }
      for (var i = 0; i < 5 && find.text(l10n.lockWrongPin).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump();
      }
      expect(find.text(l10n.lockWrongPin), findsOneWidget);
      expect(find.text('0:30'), findsOneWidget);
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, '1')).onPressed, isNull);

      await tester.pump(const Duration(seconds: 6));
      expect(find.text('0:24'), findsOneWidget);

      await tester.tap(find.text(l10n.emergencyCallButton));
      await tester.pumpAndSettle();
      expect(dialer.dialled, ['0000-1112223']);

      await tester.pump(const Duration(seconds: 24));
      now = now.add(const Duration(seconds: 30));
      expect(find.text(l10n.lockWrongPin), findsNothing);
      await typePin(tester, testPin);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a forgotten PIN is reset offline with the supervisor\'s reply code', (tester) async {
      await tester.runAsync(() => services.households.create(village: 'Kept'));
      await pumpApp(tester);
      await lockApp(tester);
      server.offline = true;

      await tester.tap(find.text(l10n.lockForgotPin));
      await tester.pumpAndSettle();
      expect(find.byType(PinResetScreen), findsOneWidget);
      final shown = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').firstWhere(
            (text) => RegExp(r'^\d{3} \d{3}$').hasMatch(text),
          );
      final challenge = shown.replaceAll(' ', '');

      await tester.enterText(find.byType(TextFormField), '11112222');
      await tapAndWait(tester, find.text(l10n.resetCheckButton));
      expect(find.text(l10n.resetWrongReply), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), server.replyCodeFor(challenge));
      await tapAndWait(tester, find.text(l10n.resetCheckButton));
      expect(find.text(l10n.pinResetNewTitle), findsOneWidget);

      await typePin(tester, '777777');
      await typePin(tester, '777777');
      await settle(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(PinResetScreen), findsNothing);
      expect((await tester.runAsync(services.households.all))!.single.village, 'Kept');
    });

    testWidgets('the emergency call offers every supervisor, and explains when no number is known', (tester) async {
      server.supervisors = [
        {'name': 'First Supervisor', 'phone': '0000-1000001'},
        {'name': 'Second Supervisor', 'phone': '0000-2000002'},
      ];
      await tester.runAsync(() => services.session.signInAgain('demo-password'));
      await pumpApp(tester);
      await lockApp(tester);

      await tester.tap(find.text(l10n.emergencyCallButton));
      await tester.pumpAndSettle();
      expect(find.text(l10n.emergencyChooseSupervisor), findsOneWidget);
      await tester.tap(find.text('Second Supervisor'));
      await tester.pumpAndSettle();
      expect(dialer.dialled, ['0000-2000002']);

      dialer.works = false;
      await tester.tap(find.text(l10n.emergencyCallButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First Supervisor'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.emergencyCallFailed('0000-1000001')), findsOneWidget);
    });

    testWidgets('locks itself after five minutes without a touch', (tester) async {
      await pumpApp(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.pump(const Duration(minutes: 4));
      await tester.tap(find.text('Demo LHW')); // a touch restarts the timer
      await tester.pump(const Duration(minutes: 4));
      expect(services.session.isUnlocked, isTrue);

      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.text(l10n.loginLockedNotice), findsOneWidget);
    });

    testWidgets('locking closes every open screen', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      await tapAndWait(tester, find.text(l10n.devHomeTitle));
      expect(find.byType(HomeScreen), findsNothing);

      await lockApp(tester);

      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('a deactivated account is locked out at the next sync, until it signs in again (M1 FE-3)', (tester) async {
      await pumpApp(tester);
      server.deactivated = true;

      await tapAndWait(tester, find.text(l10n.syncNowButton));

      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.text(l10n.loginDeactivated), findsOneWidget);
      expect(find.widgetWithText(TextButton, '1'), findsNothing, reason: 'no keypad while deactivated');

      server.deactivated = false;
      await tapAndWait(tester, find.text(l10n.homeSignInAgainButton));
      expect(find.byType(SignInAgainScreen), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'demo-password');
      await tapAndWait(tester, find.text(l10n.signInButton));

      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.text(l10n.loginDeactivated), findsNothing);
      await typePin(tester, testPin);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('after a password reset the home screen asks to sign in again; the records stay', (tester) async {
      await pumpApp(tester);
      server
        ..password = 'reset-by-admin'
        ..expireAccessTokens()
        ..validRefreshTokens.clear();

      await tapAndWait(tester, find.text(l10n.syncNowButton));
      expect(find.text(l10n.homeSyncNeedsSignIn), findsOneWidget);

      await tapAndWait(tester, find.text(l10n.homeSignInAgainButton));
      await tester.enterText(find.byType(TextFormField), 'reset-by-admin');
      await tapAndWait(tester, find.text(l10n.signInButton));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(services.session.canSync, isTrue);
    });

    testWidgets('Change PIN in the settings needs the current PIN', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      await tapAndWait(tester, find.text(l10n.pinChangeTitle));

      await typePin(tester, '000000');
      await typePin(tester, '111111');
      await typePin(tester, '111111');
      expect(find.text(l10n.pinChangeWrong), findsOneWidget);

      await typePin(tester, testPin);
      await typePin(tester, '111111');
      await typePin(tester, '111111');
      expect(find.text(l10n.pinChanged), findsOneWidget);

      await lockApp(tester);
      await typePin(tester, '111111');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('sign-out waits for records to sync, asks first, then returns to activation', (tester) async {
      await tester.runAsync(() => services.households.create(village: 'Waiting'));
      await pumpApp(tester);
      await openSettings(tester);

      await tapAndWait(tester, find.text(l10n.homeSignOutButton));
      expect(find.text(l10n.signOutBlocked(1)), findsOneWidget);
      expect(services.session.stage, SessionStage.unlocked);

      await tester.runAsync(services.session.sync);
      await tapAndWait(tester, find.text(l10n.homeSignOutButton));
      expect(find.text(l10n.signOutConfirmText), findsOneWidget);
      await tapAndWait(tester, find.widgetWithText(FilledButton, l10n.homeSignOutButton));

      expect(find.byType(ActivationScreen), findsOneWidget);
      expect(find.text(l10n.loginSignedOutNotice), findsOneWidget);
      expect(server.revokedRefreshTokens, hasLength(1));
    });
  });
}
