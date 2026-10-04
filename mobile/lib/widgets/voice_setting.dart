// M3 FE-3: the voice guidance mute toggle in the home screen's settings. Voice
// guidance exists only in Urdu (M1 FE-4, LI-6); in English a note says so.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../voice/voice_guide.dart';

class VoiceSetting extends StatefulWidget {
  const VoiceSetting({super.key, required this.guidance});

  final VoiceGuidance guidance;

  @override
  State<VoiceSetting> createState() => _VoiceSettingState();
}

class _VoiceSettingState extends State<VoiceSetting> {
  bool? _canSpeakUrdu;

  @override
  void initState() {
    super.initState();
    widget.guidance.canSpeakUrdu().then((can) {
      if (mounted) setState(() => _canSpeakUrdu = can);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = widget.guidance.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        if (!settings.voiceGuidanceAvailable) return Text(l10n.voiceGuidanceUrduOnly);
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
            if (_canSpeakUrdu == false)
              Text(l10n.voiceNoUrduVoice, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        );
      },
    );
  }
}
