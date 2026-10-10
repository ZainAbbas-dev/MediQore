// M1 FE-2: create the six-digit PIN (final design screen 2), typed twice.
// The same screen makes a new PIN after the supervisor's reply code (PIN
// reset) and changes the PIN from Settings, where the current PIN comes first.
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/app_cards.dart';
import '../widgets/curved_header.dart';
import '../widgets/pin_pad.dart';

enum PinCreateMode {
  /// Right after activation; saving the PIN finishes the activation.
  activation,

  /// After a checked supervisor reply code; saving the PIN opens the app.
  reset,

  /// Settings → Change PIN: the current PIN first.
  change,
}

enum _Step { current, enter, repeat }

class PinCreateScreen extends StatefulWidget {
  const PinCreateScreen({super.key, required this.services, required this.mode});

  final AppServices services;
  final PinCreateMode mode;

  @override
  State<PinCreateScreen> createState() => _PinCreateScreenState();
}

class _PinCreateScreenState extends State<PinCreateScreen> {
  late _Step _step = widget.mode == PinCreateMode.change ? _Step.current : _Step.enter;
  String? _current;
  String? _first;
  String? _error;
  bool _busy = false;

  Future<void> _onPin(String pin) async {
    final l10n = AppLocalizations.of(context);
    switch (_step) {
      case _Step.current:
        setState(() {
          _current = pin;
          _step = _Step.enter;
          _error = null;
        });
      case _Step.enter:
        setState(() {
          _first = pin;
          _step = _Step.repeat;
          _error = null;
        });
      case _Step.repeat:
        if (pin != _first) {
          setState(() {
            _first = null;
            _step = _Step.enter;
            _error = l10n.pinMismatch;
          });
        } else {
          await _save(pin, l10n);
        }
    }
  }

  Future<void> _save(String pin, AppLocalizations l10n) async {
    setState(() => _busy = true);
    final session = widget.services.session;
    switch (widget.mode) {
      case PinCreateMode.activation:
        await session.completeActivation(pin); // the app then shows the home screen
      case PinCreateMode.reset:
        await session.resetPin(pin); // the app then shows the home screen (or the lock screen)
      case PinCreateMode.change:
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        if (await session.changePin(_current!, pin)) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.pinChanged)));
          navigator.pop();
          return;
        }
        if (!mounted) return;
        setState(() {
          _busy = false;
          _current = null;
          _first = null;
          _step = _Step.current;
          _error = l10n.pinChangeWrong;
        });
        return;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = switch (widget.mode) {
      PinCreateMode.activation => l10n.pinCreateTitle,
      PinCreateMode.reset => l10n.pinResetNewTitle,
      PinCreateMode.change => l10n.pinChangeTitle,
    };
    final stepText = switch (_step) {
      _Step.current => l10n.pinStepCurrent,
      _Step.enter => l10n.pinStepEnter,
      _Step.repeat => l10n.pinStepRepeat,
    };
    final downloading = widget.services.session.isDownloading;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CurvedHeader(title: title, subtitle: l10n.pinCreateSubtitle),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(stepText, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_error != null) ...[NoticeCard(text: _error!, warning: true), const SizedBox(height: 12)],
                  if (_busy)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(downloading ? l10n.loginDownloading : l10n.pinSaving, textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  else
                    PinEntry(key: ValueKey(_step), onComplete: _onPin),
                  const SizedBox(height: 16),
                  Text(
                    l10n.pinCreateNote,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
