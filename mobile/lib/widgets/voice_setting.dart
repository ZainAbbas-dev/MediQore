// M3 FE-3: the voice guidance settings: the on/off switch, a button that tests
// the voice, and what to do when the phone has no Urdu voice. Voice guidance
// exists only in Urdu (M1 FE-4, LI-6); in English a note says so.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../voice/voice_guide.dart';
import 'app_cards.dart';

class VoiceSetting extends StatefulWidget {
  const VoiceSetting({super.key, required this.guidance});

  final VoiceGuidance guidance;

  @override
  State<VoiceSetting> createState() => _VoiceSettingState();
}

class _VoiceSettingState extends State<VoiceSetting> {
  bool? _canSpeakUrdu;
  bool _played = false;

  @override
  void initState() {
    super.initState();
    widget.guidance.canSpeakUrdu().then((can) {
      if (mounted) setState(() => _canSpeakUrdu = can);
    });
  }

  Future<void> _test(AppLocalizations l10n) async {
    final spoke = await widget.guidance.test(l10n.voiceTestSample);
    if (!mounted) return;
    setState(() {
      _canSpeakUrdu = spoke;
      _played = spoke;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = widget.guidance.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        if (!settings.voiceGuidanceAvailable) return NoticeCard(text: l10n.voiceGuidanceUrduOnly);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.voiceGuidanceLabel, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(l10n.voiceGuidanceHint),
              value: !settings.voiceMuted,
              onChanged: (on) => settings.setVoiceMuted(!on),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.play_circle_outline),
              label: Text(l10n.voiceTestButton),
              onPressed: () => _test(l10n),
            ),
            if (_canSpeakUrdu == false) ...[
              const SizedBox(height: 12),
              NoticeCard(text: l10n.voiceNoUrduVoice, warning: true),
            ] else if (_played) ...[
              const SizedBox(height: 12),
              NoticeCard(text: l10n.voiceTestPlayed, icon: Icons.volume_up),
            ],
          ],
        );
      },
    );
  }
}
