import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/screens/voice_check_screen.dart';
import 'package:mediqore/theme/app_theme.dart';

/// Stands in for the phone's text-to-speech engine behind flutter_tts.
class FakeTtsEngine {
  FakeTtsEngine({required this.hasUrdu});

  final bool hasUrdu;
  final List<MethodCall> calls = [];

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'isLanguageAvailable':
      case 'isLanguageInstalled':
        return hasUrdu && call.arguments == urduLanguageTag;
      case 'getEngines':
        return ['com.google.android.tts'];
      case 'getDefaultEngine':
        return 'com.google.android.tts';
      case 'getVoices':
        return [
          {'name': 'en-us-x-sfg-local', 'locale': 'en-US'},
          if (hasUrdu) {'name': 'ur-pk-x-cfn-local', 'locale': 'ur-PK'},
        ];
      case 'speak':
        return hasUrdu ? 1 : 0;
      default:
        return 1;
    }
  }
}

void main() {
  const channel = MethodChannel('flutter_tts');

  Future<FakeTtsEngine> pumpScreen(
    WidgetTester tester, {
    required bool hasUrdu,
    Size size = const Size(1080, 4000),
    Locale locale = const Locale('ur'),
  }) async {
    final engine = FakeTtsEngine(hasUrdu: hasUrdu);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, engine.handle);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(urdu: locale.languageCode == 'ur'),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const VoiceCheckScreen(),
      ),
    );
    await tester.pumpAndSettle();
    return engine;
  }

  testWidgets('a phone with an Urdu voice reports it and speaks a field label', (tester) async {
    final engine = await pumpScreen(tester, hasUrdu: true);

    expect(find.text('ہاں'), findsNWidgets(2)); // supported and installed
    expect(find.text('ur-pk-x-cfn-local (ur-PK)'), findsOneWidget);
    expect(find.text('com.google.android.tts'), findsNWidgets(2)); // default engine and engine list

    await tester.tap(find.text('نمونے کا لیبل سنائیں'));
    await tester.pumpAndSettle();
    expect(engine.calls.where((c) => c.method == 'setLanguage').single.arguments, 'ur-PK');
    final spoken = engine.calls.where((c) => c.method == 'speak').single.arguments;
    // flutter_tts sends {text, focus} on Android and the bare text elsewhere, such as the test host.
    expect(spoken is Map ? spoken['text'] : spoken, 'اوپر والا بلڈ پریشر');
    expect(find.text('نمونہ آواز کے انجن کو بھیج دیا گیا۔ کیا آپ نے صاف اردو سنی؟'), findsOneWidget);
  });

  testWidgets('a phone without an Urdu voice says so', (tester) async {
    await pumpScreen(tester, hasUrdu: false);

    expect(find.text('نہیں'), findsNWidgets(2));
    expect(find.text('کوئی نہیں'), findsOneWidget); // no Urdu voices

    await tester.tap(find.text('نمونے کا لیبل سنائیں'));
    await tester.pumpAndSettle();
    expect(find.text('آواز کا انجن نمونہ نہیں سنا سکا۔'), findsOneWidget);
  });

  testWidgets('fits a small phone (320 x 640) without overflow', (tester) async {
    await pumpScreen(tester, hasUrdu: true, size: const Size(640, 1280));
    expect(tester.takeException(), isNull);
  });

  testWidgets('in English the sample is not spoken: voice guidance is Urdu only (M1 FE-4)', (tester) async {
    final engine = await pumpScreen(tester, hasUrdu: true, locale: const Locale('en'));

    expect(find.text('Voice guidance works only in Urdu. Switch the app to Urdu to use it.'), findsOneWidget);
    final speak = tester.widget<FilledButton>(
      find.ancestor(of: find.text('Speak a sample label'), matching: find.byWidgetPredicate((w) => w is FilledButton)),
    );
    expect(speak.onPressed, isNull);

    await tester.tap(find.text('Speak a sample label'));
    await tester.pumpAndSettle();
    expect(engine.calls.where((c) => c.method == 'speak' || c.method == 'setLanguage'), isEmpty);
  });

  testWidgets('fits a small phone (320 x 640) without overflow in English', (tester) async {
    await pumpScreen(tester, hasUrdu: true, size: const Size(640, 1280), locale: const Locale('en'));
    expect(tester.takeException(), isNull);
  });
}
