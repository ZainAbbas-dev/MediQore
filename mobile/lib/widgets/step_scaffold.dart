// A data entry wizard from the final design (screens 8–11 and 15–18): the
// step line ("Step 2 of 4 · Pregnancy") with a progress bar, the step's
// content, and Back / Next at the bottom, always in reach of the thumb.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

class StepScaffold extends StatelessWidget {
  const StepScaffold({
    super.key,
    required this.title,
    required this.step,
    required this.total,
    required this.stepName,
    required this.child,
    required this.nextLabel,
    required this.onNext,
    this.onBack,
    this.statusBar,
    this.busy = false,
  });

  final String title;

  /// 1-based.
  final int step;
  final int total;
  final String stepName;
  final Widget child;

  /// "Next step", or the save button's text on the last step.
  final String nextLabel;
  final VoidCallback? onNext;

  /// The previous step; hidden on the first step (the app bar's back button
  /// leaves the form).
  final VoidCallback? onBack;

  /// For example the offline status bar.
  final Widget? statusBar;

  /// Disables both buttons, for example while saving.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?statusBar,
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.stepOf(step, total, stepName),
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
                ),
                const SizedBox(height: 6),
                Semantics(
                  label: l10n.stepOf(step, total, stepName),
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      for (var i = 1; i <= total; i++) ...[
                        if (i > 1) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: i <= step ? AppColors.primary : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (onBack != null) ...[
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(onPressed: busy ? null : onBack, child: Text(l10n.stepBack)),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 3,
                    child: FilledButton(
                      onPressed: busy ? null : onNext,
                      child: Text(nextLabel, textAlign: TextAlign.center),
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

/// A whole-number counter with − and + buttons (final design screen 11), for
/// counts such as earlier pregnancies. The number reads left to right.
class CounterField extends StatelessWidget {
  const CounterField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 30,
    this.errorText,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget button(IconData icon, String tooltip, int? next) => IconButton.filledTonal(
      icon: Icon(icon),
      tooltip: tooltip,
      iconSize: 28,
      style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
      onPressed: next == null ? null : () => onChanged(next),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
            const SizedBox(width: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  button(Icons.remove, l10n.stepperLess, value > min ? value - 1 : null),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$value',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  button(Icons.add, l10n.stepperMore, value < max ? value + 1 : null),
                ],
              ),
            ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(errorText!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ),
      ],
    );
  }
}
