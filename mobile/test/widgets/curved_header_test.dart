import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/settings/app_settings.dart';
import 'package:mediqore/theme/app_colors.dart';
import 'package:mediqore/theme/app_theme.dart';
import 'package:mediqore/widgets/curved_header.dart';

import '../helpers.dart';

// P0-2, P0-7: the teal header with rounded bottom corners of the final design.
void main() {
  Widget pushed(Locale locale) => MaterialApp(
        theme: AppTheme.light(urdu: locale == AppSettings.urdu),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: CurvedHeader(title: 'صائمہ بی بی', subtitle: 'LHW-00012-0025', overlap: 40),
                  ),
                )),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  testWidgets('shows the title and subtitle on teal with rounded bottom corners, and no back button on a first screen',
      (tester) async {
    await tester.pumpWidget(wrapInApp(const CurvedHeader(title: 'رجسٹرڈ خواتین', subtitle: '24')));
    await tester.pumpAndSettle();

    expect(find.text('رجسٹرڈ خواتین'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.byType(BackButtonIcon), findsNothing);
    final material = tester.widget<Material>(
      find.descendant(of: find.byType(CurvedHeader), matching: find.byType(Material)).first,
    );
    expect(material.color, AppColors.primary);
    expect(
      (material.shape! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.vertical(bottom: Radius.circular(AppTheme.headerRadius)),
    );
  });

  for (final locale in [AppSettings.urdu, AppSettings.english]) {
    testWidgets('a pushed screen gets a back button that goes back ($locale)', (tester) async {
      await tester.pumpWidget(pushed(locale));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BackButtonIcon), findsOneWidget);
      final back = tester.getCenter(find.byType(BackButtonIcon));
      final title = tester.getCenter(find.text('صائمہ بی بی'));
      // The back button sits at the start of the line: right in Urdu, left in English.
      expect(locale == AppSettings.urdu ? back.dx > title.dx : back.dx < title.dx, isTrue);

      await tester.tap(find.byType(BackButtonIcon));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });
  }

  testWidgets('shows actions such as the settings gear, and fits a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapInApp(CurvedHeader(
      title: 'السلام علیکم، نسرین',
      actions: [HeaderIconButton(icon: const Icon(Icons.settings), tooltip: 'ترتیبات', onPressed: () {})],
    )));
    await tester.pumpAndSettle();

    expect(find.byTooltip('ترتیبات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('the theme follows the final design: pill buttons 60 dp tall, rounded cards and fields', () {
    final theme = AppTheme.light();
    expect(AppTheme.largeControlHeight, 60);
    expect(theme.filledButtonTheme.style?.shape?.resolve({}), isA<StadiumBorder>());
    expect(theme.outlinedButtonTheme.style?.shape?.resolve({}), isA<StadiumBorder>());
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect((theme.cardTheme.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(AppTheme.radius));
    expect(
      (theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder).borderRadius,
      BorderRadius.circular(AppTheme.fieldRadius),
    );
    expect(theme.colorScheme.primary, AppColors.primary);
  });
}
