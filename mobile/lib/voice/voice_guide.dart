// M3 FE-3: voice guidance during data entry. When a field of the visit form
// gets focus, the phone reads its Urdu label aloud with flutter_tts (scope
// Tools table). It is on by default and can be muted in settings, and it is off
// while the app is in English (M1 FE-4, LI-6).
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../settings/app_settings.dart';

/// The language tag the voice is asked for.
const String urduLanguageTag = 'ur-PK';

/// What speaks: the phone's text-to-speech, or a fake in tests.
abstract interface class Voice {
  Future<void> speak(String text);
  Future<void> stop();

  /// Whether the phone can speak Urdu; null when it cannot tell.
  Future<bool?> canSpeakUrdu();
}

/// The phone's text-to-speech engine (flutter_tts), set to Urdu.
class TtsVoice implements Voice {
  TtsVoice([this._engine]);

  // Made at the first use, so creating the app's services needs no engine.
  FlutterTts? _engine;
  FlutterTts get _tts => _engine ??= FlutterTts();
  Future<bool>? _urdu;

  // True once the engine is set to Urdu. Android answers 1 when the language
  // is available, 0 when it is not.
  Future<bool> _setUrdu() => _urdu ??= _tts.setLanguage(urduLanguageTag).then((result) => result == 1 || result == true);

  @override
  Future<void> speak(String text) async {
    // Without an Urdu voice, another language's voice would garble the label.
    if (!await _setUrdu()) return;
    await _tts.stop(); // a new field interrupts the previous label
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _engine?.stop();
  }

  @override
  Future<bool?> canSpeakUrdu() async {
    final available = await _tts.isLanguageAvailable(urduLanguageTag);
    return available is bool ? available : null;
  }
}

/// Decides whether a label is read aloud: only in Urdu and only when the LHW
/// has not muted voice guidance. A phone without an Urdu voice stays silent;
/// the form works the same (decision 0004 covers recorded clips instead).
class VoiceGuidance {
  VoiceGuidance({required this.settings, required this._voice}) {
    settings.addListener(_onSettingsChanged);
  }

  final AppSettings settings;
  final Voice _voice;

  /// True while labels are read aloud.
  bool get isActive => settings.voiceGuidanceAvailable && !settings.voiceMuted;

  /// Reads [label] aloud if voice guidance is active.
  Future<void> announce(String label) async {
    if (!isActive) return;
    try {
      await _voice.speak(label);
    } on Object catch (_) {
      // No voice engine or no Urdu voice: data entry goes on without it.
    }
  }

  Future<bool?> canSpeakUrdu() async {
    try {
      return await _voice.canSpeakUrdu();
    } on Object catch (_) {
      return null;
    }
  }

  // Muting or switching to English silences a label that is being read.
  void _onSettingsChanged() {
    if (!isActive) _voice.stop().catchError((Object _) {});
  }

  void dispose() => settings.removeListener(_onSettingsChanged);
}

/// Makes [guidance] available to the form fields below it. Fields outside a
/// [VoiceScope] are never read aloud. Fields rebuild when the language or the
/// mute setting changes.
class VoiceScope extends InheritedNotifier<AppSettings> {
  VoiceScope({super.key, required this.guidance, required super.child}) : super(notifier: guidance.settings);

  final VoiceGuidance guidance;

  static VoiceGuidance? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VoiceScope>()?.guidance;
}
