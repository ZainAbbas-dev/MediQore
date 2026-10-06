import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/settings/app_settings.dart';
import 'package:mediqore/voice/voice_guide.dart';

import '../support/fake_voice.dart';

/// A voice that fails, like a phone with no text-to-speech engine.
class _BrokenVoice implements Voice {
  @override
  Future<void> speak(String text) => Future.error(PlatformException(code: 'no_engine'));

  @override
  Future<void> stop() => Future.error(PlatformException(code: 'no_engine'));

  @override
  Future<bool?> canSpeakUrdu() => Future.error(PlatformException(code: 'no_engine'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsVoice (flutter_tts)', () {
    const channel = MethodChannel('flutter_tts');
    late List<MethodCall> calls;

    // The phone's engines; [urduIn] is the one with an Urdu voice, if any.
    void engine({required bool hasUrdu, List<String> engines = const ['com.maker.tts'], String? urduIn, String urduTag = urduLanguageTag}) {
      calls = [];
      var current = engines.first;
      final withUrdu = hasUrdu ? (urduIn ?? engines.first) : null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'setLanguage' => current == withUrdu && call.arguments == urduTag ? 1 : 0,
          'getEngines' => engines,
          'getDefaultEngine' => engines.first,
          'setEngine' => () {
            current = call.arguments as String;
            return 1;
          }(),
          _ => 1,
        };
      });
    }

    Iterable<Object?> argumentsOf(String method) => calls.where((c) => c.method == method).map((c) => c.arguments);

    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    test('speaks the label in Urdu (ur-PK), interrupting the previous one', () async {
      engine(hasUrdu: true);
      final voice = TtsVoice();

      await voice.speak('اوپر والا بلڈ پریشر');
      await voice.speak('نبض');

      expect(argumentsOf('setLanguage'), [urduLanguageTag], reason: 'set once, then kept');
      expect(calls.where((c) => c.method == 'speak').map((c) => c.arguments), ['اوپر والا بلڈ پریشر', 'نبض']);
      expect(calls.where((c) => c.method == 'stop'), hasLength(2));
      expect(await voice.canSpeakUrdu(), isTrue);
    });

    test('stays silent on a phone without an Urdu voice', () async {
      engine(hasUrdu: false);
      final voice = TtsVoice();

      await voice.speak('نبض');

      expect(calls.where((c) => c.method == 'speak'), isEmpty);
      expect(await voice.canSpeakUrdu(), isFalse);
    });

    test('uses another installed engine with Urdu when the default one has none', () async {
      engine(hasUrdu: true, engines: ['com.samsung.SMT', 'com.google.android.tts'], urduIn: 'com.google.android.tts');
      final voice = TtsVoice();

      await voice.speak('نبض');

      expect(argumentsOf('setEngine'), ['com.google.android.tts']);
      expect(argumentsOf('speak'), ['نبض']);
    });

    test('accepts any Urdu voice when there is none for Pakistan', () async {
      engine(hasUrdu: true, urduTag: 'ur-IN');
      final voice = TtsVoice();

      await voice.speak('نبض');

      expect(argumentsOf('setLanguage'), [urduLanguageTag, 'ur', 'ur-IN']);
      expect(argumentsOf('speak'), ['نبض']);
    });

    test('tries again at the next label, for example after the Urdu voice was installed', () async {
      engine(hasUrdu: false);
      final voice = TtsVoice();
      await voice.speak('نبض');
      expect(argumentsOf('speak'), isEmpty);

      engine(hasUrdu: true);
      await voice.speak('نبض');

      expect(argumentsOf('speak'), ['نبض']);
    });
  });

  group('VoiceGuidance (M3 FE-3)', () {
    test('reads labels only in Urdu and only when not muted; muting stops the voice', () async {
      final settings = AppSettings();
      final voice = FakeVoice();
      final guidance = VoiceGuidance(settings: settings, voice: voice);
      addTearDown(guidance.dispose);

      await guidance.announce('نبض');
      expect(voice.spoken, ['نبض']);

      await settings.setVoiceMuted(true);
      expect(guidance.isActive, isFalse);
      expect(voice.stops, 1);
      await guidance.announce('وزن');

      await settings.setVoiceMuted(false);
      await settings.setLocale(AppSettings.english);
      expect(guidance.isActive, isFalse, reason: 'voice guidance is Urdu only (M1 FE-4)');
      await guidance.announce('Weight');

      expect(voice.spoken, ['نبض']);
    });

    test('a phone without a voice engine never stops data entry', () async {
      final settings = AppSettings();
      final guidance = VoiceGuidance(settings: settings, voice: _BrokenVoice());
      addTearDown(guidance.dispose);

      await guidance.announce('نبض');
      expect(await guidance.canSpeakUrdu(), isNull);
      await settings.setVoiceMuted(true); // stopping fails quietly too
    });
  });
}
