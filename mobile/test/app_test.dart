import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/screens/dev_home_screen.dart';
import 'package:mediqore/screens/sync_test_screen.dart';
import 'package:mediqore/screens/widget_kit_screen.dart';
import 'package:mediqore/settings/app_settings.dart';
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
    await services.settings.setLocale(AppSettings.english);
    await tester.pumpWidget(MediQoreApp(services: services));
    await tester.pumpAndSettle();

    expect(find.text('Phase 0 checks'), findsOneWidget);
    final context = tester.element(find.byType(DevHomeScreen));
    expect(Directionality.of(context), TextDirection.ltr);
  });

  testWidgets('the language switch changes the whole app at once and is saved (M1 FE-4)', (tester) async {
    final store = MemorySettingsStore();
    await services.db.close();
    services = testServices(null, AppSettings(store: store));
    await tester.pumpWidget(MediQoreApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Phase 0 checks'), findsOneWidget);
    expect(find.text('Sync test'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(DevHomeScreen))), TextDirection.ltr);
    expect(
      Theme.of(tester.element(find.byType(DevHomeScreen))).textTheme.bodyLarge?.fontFamily,
      isNot(AppTheme.urduFontFamily),
    );

    // The next app start reads the saved choice.
    expect(AppSettings(store: store).locale, AppSettings.english);

    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();
    expect(find.text('فیز 0 کی جانچ'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(DevHomeScreen))), TextDirection.rtl);
    expect(AppSettings(store: store).locale, AppSettings.urdu);
  });

  test('theme uses Jameel Noori Nastaleeq with taller lines in Urdu', () {
    final theme = AppTheme.light();
    expect(theme.textTheme.bodyLarge?.fontFamily, AppTheme.urduFontFamily);
    expect(theme.textTheme.bodyLarge?.height, AppTheme.urduLineHeight);
    // Button labels too: a button text style without the font would fall back to the system font.
    expect(theme.filledButtonTheme.style?.textStyle?.resolve({})?.fontFamily, AppTheme.urduFontFamily);
    expect(theme.outlinedButtonTheme.style?.textStyle?.resolve({})?.fontFamily, AppTheme.urduFontFamily);
  });

  test('theme uses the standard Latin font and line height in English', () {
    final theme = AppTheme.light(urdu: false);
    expect(theme.textTheme.bodyLarge?.fontFamily, isNot(AppTheme.urduFontFamily));
    expect(theme.textTheme.bodyLarge?.height, isNot(AppTheme.urduLineHeight));
    expect(theme.filledButtonTheme.style?.minimumSize?.resolve({})?.height, AppTheme.largeControlHeight);
  });

  group('on a small phone with the real Nastaliq font', () {
    setUp(() async {
      final font = FontLoader(AppTheme.urduFontFamily)
        ..addFont(rootBundle.load('assets/fonts/JameelNooriNastaleeq.ttf'));
      await font.load();
    });

    Future<void> openOnSmallPhone(WidgetTester tester, String button, Type screen, {bool english = false}) async {
      // 320 x 640 logical pixels: a small, low-cost Android phone.
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      if (english) await services.settings.setLocale(AppSettings.english);
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

    testWidgets('the widget kit fits without overflow in English', (tester) async {
      await openOnSmallPhone(tester, 'Widget kit', WidgetKitScreen, english: true);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sync test screen fits without overflow in English', (tester) async {
      await openOnSmallPhone(tester, 'Sync test', SyncTestScreen, english: true);
      expect(tester.takeException(), isNull);
    });
  });
}
