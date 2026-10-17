// M3 FE-1: the 30-second pulse counter (final design screen 16), for when the
// BP device shows no pulse. The LHW presses the big button once per beat; the
// time starts at the first press. When it is up, the app multiplies the count
// (both numbers from the Clinical Rules Table) and closes with the pulse.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../widgets/app_cards.dart';
import '../widgets/curved_header.dart';

class PulseCounterScreen extends StatefulWidget {
  const PulseCounterScreen({super.key, this.seconds = 30, this.multiplier = 2});

  final int seconds;
  final int multiplier;

  @override
  State<PulseCounterScreen> createState() => _PulseCounterScreenState();
}

class _PulseCounterScreenState extends State<PulseCounterScreen> with SingleTickerProviderStateMixin {
  /// One heart beat on the button for every tap, so each counted beat is felt
  /// and seen without looking at the number.
  late final AnimationController _beatPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
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
    _beatPulse.dispose();
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
    HapticFeedback.selectionClick();
    if (AppMotion.of(context, AppMotion.short) > Duration.zero) _beatPulse.forward(from: 0);
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
          CurvedHeader(title: l10n.pulseTitle, close: true),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      clock,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Text(
                    _done
                        ? l10n.pulseDone(widget.seconds)
                        : _running
                        ? ''
                        : l10n.pulseTapToStart,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 16),
                  // The big button in a light teal ring (final design 16); it
                  // keeps the count when the time is up.
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                      child: SizedBox.square(
                        dimension: 180,
                        child: FilledButton(
                          onPressed: _done ? null : _beat,
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                            disabledBackgroundColor: AppColors.primary,
                            disabledForegroundColor: Colors.white,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedBuilder(
                                animation: _beatPulse,
                                builder: (context, heart) =>
                                    Transform.scale(scale: 1 + 0.28 * sin(_beatPulse.value * pi), child: heart),
                                child: Icon(_done ? Icons.favorite_border : Icons.favorite, size: 44),
                              ),
                              Text(
                                '$_beats',
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, fontFamily: 'sans-serif', height: 1.1),
                              ),
                              Text(
                                _done ? l10n.pulseCountedLabel : l10n.pulseTapButton,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The explanation under the button, so the button is always in
                  // sight, even on a small phone.
                  if (!_done) ...[
                    const SizedBox(height: 20),
                    InfoPanel(
                      text: '${l10n.pulseIntro} ${l10n.pulseMultiplyNote(widget.seconds, widget.multiplier)}',
                      icon: Icons.touch_app_outlined,
                    ),
                  ],
                  if (_done) ...[
                    const SizedBox(height: 20),
                    // The result rises into place when the time is up.
                    EnterTransition(offset: const Offset(0, 16), child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            Text(
                              l10n.pulseResultLabel,
                              style: theme.textTheme.titleMedium?.copyWith(color: AppColors.mutedText),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerEnd,
                                child: Text(
                                  '$_beats × ${widget.multiplier} = $pulse ${l10n.unitPerMinute}',
                                  textDirection: TextDirection.ltr,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
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
                    child: OutlinedButton(
                      onPressed: _beats == 0 ? null : _restart,
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: Text(l10n.pulseRestart, textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _done && _beats > 0 ? () => Navigator.of(context).pop(pulse) : null,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: Text(l10n.pulseUse, textAlign: TextAlign.center),
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
