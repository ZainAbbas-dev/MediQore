import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/screens/sync_test_screen.dart';
import 'package:mediqore/theme/app_theme.dart';

import '../helpers.dart';
import '../support/fake_sync_server.dart';

void main() {
  late FakeSyncServer server;
  late AppServices services;

  setUp(() {
    server = FakeSyncServer();
    services = testServices(server);
  });
  tearDown(() => services.db.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    // Tall enough that the whole list is built, so every line can be found.
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('ur'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: SyncTestScreen(services: services),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  // Drift and the fake HTTP client finish their work outside the test's fake
  // clock, so each action runs inside runAsync before the screen is rebuilt.
  Future<void> tapAndWait(WidgetTester tester, String text) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(text));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('a household made offline is pushed after signing in', (tester) async {
    await pumpScreen(tester);

    // Offline: the record is saved on the phone and queued.
    await tapAndWait(tester, 'ٹیسٹ گھرانہ بنائیں');
    expect(find.text('سنک کا انتظار ہے'), findsOneWidget);
    expect(find.text('آف لائن: انٹرنیٹ ملنے پر ڈیٹا بھیج دیا جائے گا'), findsOneWidget);

    // Sync is not possible before signing in.
    final syncButton = tester.widget<FilledButton>(find.ancestor(of: find.text('سنک کے لیے سائن ان کریں'), matching: find.byType(FilledButton)));
    expect(syncButton.onPressed, isNull);

    await tester.enterText(find.byType(TextFormField).at(0), 'lhw.demo');
    await tester.enterText(find.byType(TextFormField).at(1), 'demo-password');
    await tapAndWait(tester, 'سائن ان کریں');
    expect(find.text('lhw.demo کے طور پر سائن ان'), findsOneWidget);

    await tapAndWait(tester, 'ابھی سنک کریں');

    expect(server.records, hasLength(1));
    expect(find.text('بھیجے گئے 1، موصول 1، مسترد 0'), findsOneWidget);
    expect(find.text('سرور نمبر 1'), findsOneWidget);
    expect(find.text('آن لائن: تمام ڈیٹا بھیج دیا گیا ہے'), findsOneWidget);
  });

  testWidgets('a wrong password shows the reason and keeps the form', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'lhw.demo');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tapAndWait(tester, 'سائن ان کریں');

    expect(find.text('سائن ان نہیں ہو سکا: INVALID_CREDENTIALS'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
