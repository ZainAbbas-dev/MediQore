// M3 FE-3: voice guidance during data entry. When a field of a data entry form
// (registration, visit) gets focus, the phone reads its Urdu label aloud with
// flutter_tts (scope Tools table). It is on by default and can be muted in
// settings, and it is off while the app is in English (M1 FE-4, LI-6).
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../settings/app_settings.dart';

/// The language tag the voice is asked for first.
const String urduLanguageTag = 'ur-PK';

/// Every tag tried, in order: Pakistan's Urdu, then any Urdu voice.
const List<String> urduLanguageTags = [urduLanguageTag, 'ur', 'ur-IN'];

/// What speaks: the phone's text-to-speech, or a fake in tests.
abstract interface class Voice {
  Future<void> speak(String text);
  Future<void> stop();

  /// Whether the phone can speak Urdu; null when it cannot tell.
  Future<bool?> canSpeakUrdu();
}

/// The phone's text-to-speech engine (flutter_tts), set to Urdu.
///
/// Many phones' default engine (often the maker's own) has no Urdu while
/// another installed engine, such as Google's, does: then that engine is used.
/// A failed attempt is tried again at the next label, for example after the
/// LHW has installed the Urdu voice data.
class TtsVoice implements Voice {
  TtsVoice([this._engine]);

  // Made at the first use, so creating the app's services needs no engine.
  FlutterTts? _engine;
  FlutterTts get _tts => _engine ??= FlutterTts();
  Future<bool>? _urdu;

  // True once an engine is set to Urdu.
  Future<bool> _setUrdu() {
    final attempt = _urdu ??= _findUrdu().catchError((Object _) => false);
    attempt.then((ok) {
      if (!ok && identical(_urdu, attempt)) _urdu = null;
    });
    return attempt;
  }

  Future<bool> _findUrdu() async {
    if (await _trySetUrdu()) return true;
    final engines = ((await _tts.getEngines) as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final defaultEngine = '${await _tts.getDefaultEngine}';
    for (final engine in engines.where((e) => e != defaultEngine)) {
      await _tts.setEngine(engine);
      if (await _trySetUrdu()) return true;
    }
    if (engines.length > 1) await _tts.setEngine(defaultEngine);
    return false;
  }

  // Android answers 1 when the language is available, 0 when it is not (also
  // when the engine knows Urdu but its voice data is not on the phone).
  Future<bool> _trySetUrdu() async {
    for (final tag in urduLanguageTags) {
      final result = await _tts.setLanguage(tag);
      if (result == 1 || result == true) return true;
    }
    return false;
  }

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
  Future<bool?> canSpeakUrdu() => _setUrdu();
}

/// Decides whether a label is read aloud: only in Urdu and only when the LHW
/// has not muted voice guidance. A phone without an Urdu voice stays silent;
/// the form works the same (decision 0004 covers recorded clips instead).
/// The settings screen says so and has a button to test the voice.
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

  /// The settings' "test the voice" button: speaks [sample] even while voice
  /// guidance is muted. False when the phone has no Urdu voice.
  Future<bool> test(String sample) async {
    if (await canSpeakUrdu() == false) return false;
    try {
      await _voice.speak(sample);
      return true;
    } on Object catch (_) {
      return false;
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

  static VoiceGuidance? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<VoiceScope>()?.guidance;
}
