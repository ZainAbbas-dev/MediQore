import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/screens/dev_home_screen.dart';
import 'package:mediqore/screens/sync_test_screen.dart';
import 'package:mediqore/screens/widget_kit_screen.dart';
import 'package:mediqore/theme/app_theme.dart';

import 'helpers.dart';

void main() {
  late AppServices services;

  setUp(() => services = testServices());
  tearDown(() => services.db.close());

  testWidgets('app starts in Urdu with a right-to-left layout', (tester) async {
    await tester.pumpWidget(MediQoreApp(services: services));
    await tester.pumpAndSettle();

    expect(find.byType(DevHomeScreen), findsOneWidget);
    expect(find.text('فیز 0 کی جانچ'), findsOneWidget);
    final context = tester.element(find.byType(DevHomeScreen));
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('English strings exist for every key', (tester) async {
    await tester.pumpWidget(MediQoreApp(services: services, locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Phase 0 checks'), findsOneWidget);
    final context = tester.element(find.byType(DevHomeScreen));
    expect(Directionality.of(context), TextDirection.ltr);
  });

  test('theme uses Jameel Noori Nastaleeq with taller lines', () {
    final theme = AppTheme.light();
    expect(theme.textTheme.bodyLarge?.fontFamily, AppTheme.urduFontFamily);
    expect(theme.textTheme.bodyLarge?.height, AppTheme.urduLineHeight);
  });

  group('on a small phone with the real Nastaliq font', () {
    setUp(() async {
      final font = FontLoader(AppTheme.urduFontFamily)
        ..addFont(rootBundle.load('assets/fonts/JameelNooriNastaleeq.ttf'));
      await font.load();
    });

    Future<void> openOnSmallPhone(WidgetTester tester, String button, Type screen) async {
      // 320 x 640 logical pixels: a small, low-cost Android phone.
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MediQoreApp(services: services));
      await tester.pumpAndSettle();
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
    }

    testWidgets('the widget kit fits without overflow', (tester) async {
      await openOnSmallPhone(tester, 'ویجٹ کٹ', WidgetKitScreen);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sync test screen fits without overflow', (tester) async {
      await openOnSmallPhone(tester, 'ڈیٹا سنک کی جانچ', SyncTestScreen);
      expect(tester.takeException(), isNull);
    });
  });
}
