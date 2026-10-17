import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/settings/app_settings.dart';
import 'package:mediqore/theme/app_motion.dart';
import 'package:mediqore/widgets/pin_pad.dart';
import 'package:mediqore/widgets/step_scaffold.dart';

import '../helpers.dart';

/// Motion is short, used only where it tells something, and switched off when
/// the phone asks for no animations.
void main() {
  double opacityOf(WidgetTester tester, String text) =>
      tester.widget<Opacity>(find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first).opacity;

  testWidgets('new content fades in, and is shown at once with "Remove animations" on', (tester) async {
    await tester.pumpWidget(wrapInApp(const EnterTransition(child: Text('سلام'))));
    expect(opacityOf(tester, 'سلام'), lessThan(1));
    await tester.pumpAndSettle();
    expect(opacityOf(tester, 'سلام'), 1);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: wrapInApp(const EnterTransition(key: ValueKey('again'), child: Text('سلام'))),
      ),
    );
    await tester.pump();
    expect(opacityOf(tester, 'سلام'), 1);
  });

  testWidgets('a wizard step slides in from the side it comes from, mirrored in Urdu', (tester) async {
    Future<double> startOfStep(int step, {required Locale locale}) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: StepScaffold(
            title: 'T',
            step: step,
            total: 3,
            stepName: 'S',
            nextLabel: 'N',
            onNext: () {},
            child: Center(child: Text('content $step')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));
      return tester.getCenter(find.text('content $step')).dx;
    }

    for (final locale in [AppSettings.english, AppSettings.urdu]) {
      await startOfStep(1, locale: locale);
      await tester.pumpAndSettle();
      final settled = tester.getCenter(find.text('content 1')).dx;
      final nextStart = await startOfStep(2, locale: locale);
      // Next: from the end side, the right in English and the left in Urdu.
      expect(nextStart > settled, locale == AppSettings.english, reason: '$locale');
      await tester.pumpAndSettle();
      final backStart = await startOfStep(1, locale: locale);
      expect(backStart < settled, locale == AppSettings.english, reason: '$locale');
      await tester.pumpAndSettle();
    }
  });

  testWidgets('a wrong PIN shakes the dots, gives a buzz and empties them', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final controller = PinEntryController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(wrapInApp(PinEntry(controller: controller, onComplete: (_) {})));
    for (final digit in ['1', '2', '3']) {
      await tester.tap(find.text(digit));
    }
    await tester.pumpAndSettle();
    final rest = tester.getCenter(find.byType(PinDots));

    controller.reject();
    await tester.pump(); // the shake starts on this frame
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getCenter(find.byType(PinDots)), isNot(rest), reason: 'shaking');
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.byType(PinDots)), rest);
    expect(tester.widget<PinDots>(find.byType(PinDots)).filled, 0);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
  });
}
