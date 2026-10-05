import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/screens/login_screen.dart';
import 'package:mediqore/settings/app_settings.dart';
import 'package:mediqore/theme/app_theme.dart';

import '../helpers.dart';
import '../support/fake_sync_server.dart';

/// The server address on the sign-in screen of a test build (M1 FE-2), which
/// testers point at a laptop on the same Wi-Fi.
void main() {
  group('serverAddressFrom', () {
    test('keeps an http or https address without spaces or a final slash', () {
      expect(serverAddressFrom(' http://192.168.1.20:3000/api/v1/ '), 'http://192.168.1.20:3000/api/v1');
      expect(serverAddressFrom('https://staging.example.org/api/v1'), 'https://staging.example.org/api/v1');
    });

    test('adds /api/v1 to an address without a path', () {
      expect(serverAddressFrom('http://192.168.1.20:3000'), 'http://192.168.1.20:3000/api/v1');
      expect(serverAddressFrom('http://192.168.1.20:3000/'), 'http://192.168.1.20:3000/api/v1');
    });

    test('refuses anything that is not an http or https address', () {
      for (final text in ['', '192.168.1.20:3000', 'ftp://192.168.1.20', 'http://', 'http:///api/v1', 'not an address']) {
        expect(serverAddressFrom(text), isNull, reason: text);
      }
    });
  });

  late FakeSyncServer server;
  late AppSettings settings;
  late AppServices services;

  setUp(() {
    server = FakeSyncServer();
    settings = AppSettings(store: MemorySettingsStore());
    services = testServices(server, settings);
  });
  tearDown(() => services.dispose());

  // A small phone (360 x 640 dp), where tall Nastaliq text overflows first.
  Future<AppLocalizations> pumpLogin(WidgetTester tester, Locale locale, {bool showServerSetting = true}) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(urdu: locale == AppSettings.urdu),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: LoginScreen(services: services, showServerSetting: showServerSetting),
      ),
    );
    await tester.pumpAndSettle();
    return lookupAppLocalizations(locale);
  }

  Finder dialogField() => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));

  Future<void> openDialog(WidgetTester tester, AppLocalizations l10n) async {
    await tester.ensureVisible(find.text(l10n.loginServerChange));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.loginServerChange));
    await tester.pumpAndSettle();
  }

  for (final locale in AppSettings.languages) {
    testWidgets('changes the server address and keeps it (${locale.languageCode})', (tester) async {
      final l10n = await pumpLogin(tester, locale);
      expect(find.text('http://test/api/v1'), findsOneWidget);

      await openDialog(tester, l10n);
      expect(find.text(l10n.loginServerTitle), findsOneWidget);
      await tester.enterText(dialogField(), '192.168.1.20:3000');
      await tester.tap(find.text(l10n.loginServerSave));
      await tester.pumpAndSettle();
      expect(find.text(l10n.loginServerInvalid), findsOneWidget);

      await tester.enterText(dialogField(), 'http://192.168.1.20:3000');
      await tester.tap(find.text(l10n.loginServerSave));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('http://192.168.1.20:3000/api/v1'), findsOneWidget);
      expect(services.serverAddress, 'http://192.168.1.20:3000/api/v1');
      expect(settings.serverAddress, 'http://192.168.1.20:3000/api/v1', reason: 'kept for the next app start');
      expect(tester.takeException(), isNull, reason: 'no overflow on a small phone');

      // Sign-in now goes to the new server.
      await tester.runAsync(() => services.session.signIn(server.username, server.password));
      expect(server.urls.last.toString(), startsWith('http://192.168.1.20:3000/api/v1/auth/login'));
    });
  }

  testWidgets('Cancel keeps the old address', (tester) async {
    final l10n = await pumpLogin(tester, AppSettings.urdu);
    await openDialog(tester, l10n);
    await tester.enterText(dialogField(), 'http://192.168.1.20:3000');
    await tester.tap(find.text(l10n.loginServerCancel));
    await tester.pumpAndSettle();

    expect(services.serverAddress, 'http://test/api/v1');
    expect(settings.serverAddress, isNull);
  });

  testWidgets('builds for LHWs do not show the server address', (tester) async {
    final l10n = await pumpLogin(tester, AppSettings.urdu, showServerSetting: false);
    expect(find.text(l10n.loginServerLabel), findsNothing);
    expect(find.text('http://test/api/v1'), findsNothing);
  });
}
