import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/app.dart';
import 'package:mediqore/screens/widget_kit_screen.dart';
import 'package:mediqore/theme/app_theme.dart';

void main() {
  testWidgets('app starts in Urdu with a right-to-left layout', (tester) async {
    await tester.pumpWidget(const MediQoreApp());
    await tester.pumpAndSettle();

    expect(find.byType(WidgetKitScreen), findsOneWidget);
    expect(find.text('ویجٹ کٹ'), findsOneWidget);
    final context = tester.element(find.byType(WidgetKitScreen));
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('English strings exist for every key', (tester) async {
    await tester.pumpWidget(const MediQoreApp(locale: Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Widget kit'), findsOneWidget);
    final context = tester.element(find.byType(WidgetKitScreen));
    expect(Directionality.of(context), TextDirection.ltr);
  });

  test('theme uses Jameel Noori Nastaleeq with taller lines', () {
    final theme = AppTheme.light();
    expect(theme.textTheme.bodyLarge?.fontFamily, AppTheme.urduFontFamily);
    expect(theme.textTheme.bodyLarge?.height, AppTheme.urduLineHeight);
  });

  testWidgets('widget kit fits a small phone without overflow', (tester) async {
    // 320 x 640 logical pixels: a small, low-cost Android phone.
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MediQoreApp());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
