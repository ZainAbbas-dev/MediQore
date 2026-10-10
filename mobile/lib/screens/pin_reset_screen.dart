// M1 FE-2: offline PIN reset (final design screen 5). Step 1 shows a 6-digit
// code to read to the supervisor; step 2 takes the 8-digit reply she reads
// back from the portal. The phone checks it with the secret it received at
// activation, without the internet, then the LHW creates a new PIN. The
// records on the phone stay as they are.
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/app_cards.dart';
import '../widgets/curved_header.dart';
import '../widgets/emergency_call_button.dart';
import '../widgets/form_fields.dart';
import '../widgets/large_button.dart';
import 'pin_create_screen.dart';

class PinResetScreen extends StatefulWidget {
  const PinResetScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<PinResetScreen> createState() => _PinResetScreenState();
}

class _PinResetScreenState extends State<PinResetScreen> {
  late final String _challenge = widget.services.session.newResetChallenge();
  final _reply = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _check(AppLocalizations l10n) async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await widget.services.session.checkResetReply(_challenge, _reply.text);
    if (!mounted) return;
    setState(() => _checking = false);
    if (!ok) {
      setState(() => _error = l10n.resetWrongReply);
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PinCreateScreen(services: widget.services, mode: PinCreateMode.reset),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // The code in two groups of three, left to right: 483 917.
    final shown = '${_challenge.substring(0, 3)} ${_challenge.substring(3)}';

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CurvedHeader(title: l10n.resetTitle, subtitle: l10n.resetIntro),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepCard(
                    number: 1,
                    title: l10n.resetStep1,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          shown,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                            color: AppColors.primaryDark,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ),
                      Text(l10n.resetStep1Hint, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _StepCard(
                    number: 2,
                    title: l10n.resetStep2,
                    children: [
                      AppTextField(
                        label: l10n.resetStep2,
                        controller: _reply,
                        ltr: true,
                        keyboardType: TextInputType.number,
                        maxLength: 9,
                      ),
                      if (_error != null) NoticeCard(text: _error!, warning: true),
                      LargeButton(
                        label: l10n.resetCheckButton,
                        icon: Icons.lock_reset,
                        onPressed: _checking ? null : () => _check(l10n),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.resetNote,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 16),
                  EmergencyCallButton(services: widget.services, label: l10n.resetCallSupervisor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A numbered step in a white card.
class _StepCard extends StatelessWidget {
  const _StepCard({required this.number, required this.title, required this.children});

  final int number;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  child: Text('$number', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
              ],
            ),
            for (final child in children) ...[const SizedBox(height: 12), child],
          ],
        ),
      ),
    );
  }
}
