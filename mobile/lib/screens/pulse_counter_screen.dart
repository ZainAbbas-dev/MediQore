// M3 FE-1: the 30-second pulse counter (final design screen 16), for when the
// BP device shows no pulse. The LHW presses the big button once per beat; the
// time starts at the first press. When it is up, the app multiplies the count
// (both numbers from the Clinical Rules Table) and closes with the pulse.
import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/curved_header.dart';

class PulseCounterScreen extends StatefulWidget {
  const PulseCounterScreen({super.key, this.seconds = 30, this.multiplier = 2});

  final int seconds;
  final int multiplier;

  @override
  State<PulseCounterScreen> createState() => _PulseCounterScreenState();
}

class _PulseCounterScreenState extends State<PulseCounterScreen> {
  int _beats = 0;
  int _left = 0;
  bool _done = false;
  Timer? _timer;

  bool get _running => _timer != null && !_done;

  @override
  void initState() {
    super.initState();
    _left = widget.seconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _beat() {
    if (_done) return;
    _timer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _left--;
        if (_left <= 0) {
          _left = 0;
          _done = true;
          timer.cancel();
        }
      });
    });
    setState(() => _beats++);
  }

  void _restart() {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _beats = 0;
      _left = widget.seconds;
      _done = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pulse = _beats * widget.multiplier;
    final clock = '${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CurvedHeader(title: l10n.pulseTitle),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.pulseIntro, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                  Text(
                    l10n.pulseMultiplyNote(widget.seconds, widget.multiplier),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      clock,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_done)
                    Center(
                      child: SizedBox.square(
                        dimension: 200,
                        child: FilledButton(
                          onPressed: _beat,
                          style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.favorite, size: 48),
                              Text(
                                l10n.pulseTapButton,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '$_beats',
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(l10n.pulseDone(widget.seconds), style: theme.textTheme.titleMedium),
                            Text(l10n.pulseBeats(_beats), style: theme.textTheme.bodyLarge),
                            const SizedBox(height: 8),
                            Text(
                              '$_beats × ${widget.multiplier} = $pulse ${l10n.unitPerMinute}',
                              textDirection: TextDirection.ltr,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!_running && !_done) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.pulseTapToStart,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(onPressed: _beats == 0 ? null : _restart, child: Text(l10n.pulseRestart)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: FilledButton(
                      onPressed: _done && _beats > 0 ? () => Navigator.of(context).pop(pulse) : null,
                      child: Text(l10n.pulseUse),
                    ),
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
