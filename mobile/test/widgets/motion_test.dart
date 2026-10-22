import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/settings/app_settings.dart';
import 'package:mediqore/theme/app_motion.dart';
import 'package:mediqore/theme/app_theme.dart';
import 'package:mediqore/widgets/pin_pad.dart';
import 'package:mediqore/widgets/step_scaffold.dart';

import '../helpers.dart';

/// Motion is light: 150–250 ms fades, slide-ups for forms and a card that
/// expands into its screen; nothing moves when the phone asks for no animations.
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

  testWidgets('a wizard step fades in where it stands, in both languages; the first step does not animate', (tester) async {
    Future<void> showStep(int step, {required Locale locale}) => tester.pumpWidget(
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

    for (final locale in [AppSettings.english, AppSettings.urdu]) {
      await showStep(1, locale: locale);
      await tester.pump();
      expect(find.ancestor(of: find.text('content 1'), matching: find.byType(Opacity)), findsNothing);
      final settled = tester.getCenter(find.text('content 1'));

      await showStep(2, locale: locale);
      await tester.pump(const Duration(milliseconds: 40));
      expect(opacityOf(tester, 'content 2'), lessThan(1), reason: '$locale');
      expect(tester.getCenter(find.text('content 2')), settled, reason: 'no slide ($locale)');
      await tester.pump(AppMotion.medium);
      expect(opacityOf(tester, 'content 2'), 1);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a wrong PIN gives a buzz and empties the dots, which stay still', (tester) async {
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getCenter(find.byType(PinDots)), rest);
    expect(tester.widget<PinDots>(find.byType(PinDots)).filled, 0);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
  });

  group('opening screens', () {
    final navigator = GlobalKey<NavigatorState>();
    const cardKey = Key('card');

    Future<void> pumpHost(WidgetTester tester, {bool still = false}) async {
      final app = MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.light(urdu: false),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: SizedBox(key: cardKey, width: 200, height: 80, child: Card(child: Text('card'))),
            ),
          ),
        ),
      );
      await tester.pumpWidget(still ? MediaQuery(data: const MediaQueryData(disableAnimations: true), child: app) : app);
    }

    const page = Scaffold(body: Center(child: Text('page')));

    test('every duration is 150–250 ms, with a linear or ease-out curve', () {
      for (final duration in [AppMotion.short, AppMotion.medium, AppMotion.long, AppMotion.sheet.duration!, AppMotion.sheet.reverseDuration!]) {
        expect(duration.inMilliseconds, inInclusiveRange(150, 250));
      }
      expect(AppMotion.enter, Curves.easeOut);
      expect(AppMotion.standard, Curves.linear);
      expect(const FadePageTransitionsBuilder().transitionDuration, AppMotion.medium);
      expect(
        AppTheme.light(urdu: true).pageTransitionsTheme.builders[TargetPlatform.android],
        isA<FadePageTransitionsBuilder>(),
      );
    });

    testWidgets('a screen fades in over the old one, which stays still', (tester) async {
      await pumpHost(tester);
      final cardAt = tester.getTopLeft(find.byKey(cardKey));
      navigator.currentState!.push(AppRoutes.screen<void>(page));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final fade = tester.widget<FadeTransition>(find.ancestor(of: find.text('page'), matching: find.byType(FadeTransition)).first);
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      expect(tester.getCenter(find.text('page')), tester.getCenter(find.byType(Navigator)), reason: 'no slide');
      expect(tester.getTopLeft(find.byKey(cardKey)), cardAt);
      await tester.pump(AppMotion.medium);
      expect(fade.opacity.value, 1);
    });

    testWidgets('a form slides up from the bottom edge and back down', (tester) async {
      await pumpHost(tester);
      final settledY = tester.getCenter(find.byType(Navigator)).dy;
      navigator.currentState!.push(AppRoutes.form<void>(page));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final midY = tester.getCenter(find.text('page')).dy;
      expect(midY, greaterThan(settledY));
      expect(tester.getCenter(find.text('page')).dx, tester.getCenter(find.byType(Navigator)).dx, reason: 'vertical only');
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('page')).dy, settledY);

      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getCenter(find.text('page')).dy, greaterThan(settledY));
      await tester.pumpAndSettle();
      expect(find.text('page'), findsNothing);
    });

    testWidgets("a card expands into the screen: the clip starts at the card's outline and grows to the full screen", (tester) async {
      await pumpHost(tester);
      final card = tester.element(find.byKey(cardKey));
      final cardRect = tester.getRect(find.byKey(cardKey));
      navigator.currentState!.push(AppRoutes.fromCard<void>(card, page));
      // The first frame of a new screen is built offstage, already complete.
      await tester.pump();
      await tester.pump();

      ClipRRect clip() => tester.widget<ClipRRect>(find.ancestor(of: find.text('page'), matching: find.byType(ClipRRect)).first);
      RRect clipNow() => clip().clipper!.getClip(Size.infinite);
      expect(clipNow().outerRect, cardRect);
      await tester.pump(const Duration(milliseconds: 100));
      final mid = clipNow().outerRect;
      expect(mid.width, inExclusiveRange(cardRect.width, 800));
      expect(mid.contains(cardRect.center), isTrue);
      await tester.pumpAndSettle();
      expect(find.ancestor(of: find.text('page'), matching: find.byType(ClipRRect)), findsNothing, reason: 'no clip once open');
    });

    testWidgets('with "Remove animations" on, every kind of screen opens at once', (tester) async {
      await pumpHost(tester, still: true);
      final card = tester.element(find.byKey(cardKey));
      for (final route in [AppRoutes.screen<void>(page), AppRoutes.form<void>(page), AppRoutes.fromCard<void>(card, page)]) {
        navigator.currentState!.push(route);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.ancestor(of: find.text('page'), matching: find.byType(FadeTransition)), findsNothing);
        expect(find.ancestor(of: find.text('page'), matching: find.byType(SlideTransition)), findsNothing);
        expect(find.ancestor(of: find.text('page'), matching: find.byType(ClipRRect)), findsNothing);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
      }
    });
  });
}
