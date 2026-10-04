// M3 FE-3: Phase 0 Urdu voice check (P0-11). Shows whether this phone's
// text-to-speech can read Urdu labels aloud, so the team can choose between the
// phone's voice and recorded clips (roadmap, Risks: "Urdu voice on the phone").
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../voice/voice_guide.dart' show urduLanguageTag;
import '../widgets/large_button.dart';

/// What the phone's text-to-speech reported for Urdu.
class VoiceCheckResult {
  const VoiceCheckResult({
    required this.languageAvailable,
    required this.languageInstalled,
    required this.defaultEngine,
    required this.engines,
    required this.urduVoices,
  });

  final bool? languageAvailable;
  final bool? languageInstalled;
  final String? defaultEngine;
  final List<String> engines;
  final List<String> urduVoices;
}

/// Asks the text-to-speech engine about Urdu support.
Future<VoiceCheckResult> checkUrduVoice(FlutterTts tts) async {
  final available = await tts.isLanguageAvailable(urduLanguageTag);
  final installed = await tts.isLanguageInstalled(urduLanguageTag);
  final engines = (await tts.getEngines as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
  final voices = (await tts.getVoices as List?) ?? const [];
  final urduVoices = [
    for (final voice in voices.whereType<Map>())
      if ('${voice['locale']}'.toLowerCase().startsWith('ur')) '${voice['name']} (${voice['locale']})',
  ];
  return VoiceCheckResult(
    languageAvailable: available is bool ? available : null,
    languageInstalled: installed is bool ? installed : null,
    defaultEngine: (await tts.getDefaultEngine)?.toString(),
    engines: engines,
    urduVoices: urduVoices,
  );
}

/// Developer screen for the Phase 0 voice check. Replaced by voice guidance on
/// the visit form in Phase 1 (M3 FE-3).
class VoiceCheckScreen extends StatefulWidget {
  const VoiceCheckScreen({super.key, this.tts});

  /// The engine to check; a new [FlutterTts] when null.
  final FlutterTts? tts;

  @override
  State<VoiceCheckScreen> createState() => _VoiceCheckScreenState();
}

class _VoiceCheckScreenState extends State<VoiceCheckScreen> {
  late final FlutterTts _tts = widget.tts ?? FlutterTts();
  VoiceCheckResult? _result;
  String? _error;
  String? _speakMessage;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await checkUrduVoice(_tts);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _speakSample(AppLocalizations l10n) async {
    bool ok;
    try {
      await _tts.setLanguage(urduLanguageTag);
      ok = await _tts.speak(l10n.fieldSystolicBp) == 1; // a real field label, as voice guidance will read it
    } catch (_) {
      ok = false;
    }
    if (mounted) setState(() => _speakMessage = ok ? l10n.voiceCheckSpoken : l10n.voiceCheckSpeakFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = _result;
    // Voice guidance reads Urdu labels only, so speaking is off in English (M1 FE-4, LI-6).
    final canSpeak = AppSettings.voiceGuidanceAvailableFor(Localizations.localeOf(context));
    String yesNo(bool? value) =>
        value == null ? l10n.voiceCheckUnknown : (value ? l10n.voiceCheckYes : l10n.voiceCheckNo);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.voiceCheckTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.voiceCheckIntro),
          const SizedBox(height: 16),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(l10n.voiceCheckError(_error!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (result != null) ...[
            _Fact(label: l10n.voiceCheckLanguageAvailable, values: [yesNo(result.languageAvailable)]),
            _Fact(label: l10n.voiceCheckLanguageInstalled, values: [yesNo(result.languageInstalled)]),
            _Fact(label: l10n.voiceCheckUrduVoices, values: result.urduVoices, none: l10n.voiceCheckNone, ltr: true),
            _Fact(
              label: l10n.voiceCheckDefaultEngine,
              values: [?result.defaultEngine],
              none: l10n.voiceCheckUnknown,
              ltr: true,
            ),
            _Fact(label: l10n.voiceCheckEngines, values: result.engines, none: l10n.voiceCheckNone, ltr: true),
          ],
          const SizedBox(height: 16),
          if (!canSpeak) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l10n.voiceGuidanceUrduOnly)),
          LargeButton(
            label: l10n.voiceCheckSpeak,
            icon: Icons.volume_up,
            onPressed: _busy || !canSpeak ? null : () => _speakSample(l10n),
          ),
          if (_speakMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_speakMessage!)),
          const SizedBox(height: 12),
          LargeButton(
            label: l10n.voiceCheckAgain,
            icon: Icons.refresh,
            secondary: true,
            onPressed: _busy ? null : _check,
          ),
        ],
      ),
    );
  }
}

/// One labelled result. Engine and voice names are Latin, so [ltr] keeps them
/// left to right inside the Urdu layout.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.values, this.none, this.ltr = false});

  final String label;
  final List<String> values;
  final String? none;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final shown = values.isEmpty && none != null ? [none!] : values;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          for (final value in shown) Text(value, textDirection: ltr && values.isNotEmpty ? TextDirection.ltr : null),
        ],
      ),
    );
  }
}
