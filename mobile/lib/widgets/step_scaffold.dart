// A data entry wizard from the final design (screens 8–11 and 15–18): the
// teal header with the close button, the title and the step line ("Step 2 of
// 4 · Pregnancy") with a progress bar, the sync status, the step's content, and
// Back / Next at the bottom, always in reach of the thumb.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'curved_header.dart';

class StepScaffold extends StatefulWidget {
  const StepScaffold({
    super.key,
    required this.title,
    this.subtitle,
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

  /// For example the woman's name and patient ID.
  final String? subtitle;

  /// 1-based.
  final int step;
  final int total;
  final String stepName;
  final Widget child;

  /// "Next step", or the save button's text on the last step.
  final String nextLabel;
  final VoidCallback? onNext;

  /// The previous step; hidden on the first step (the header's close button
  /// leaves the form).
  final VoidCallback? onBack;

  /// The sync state, at the end of the header: a compact [LiveStatusBar].
  final Widget? statusBar;

  /// Disables both buttons, for example while saving.
  final bool busy;

  @override
  State<StepScaffold> createState() => _StepScaffoldState();
}

class _StepScaffoldState extends State<StepScaffold> {
  /// Set once the step has changed: each new step fades in. The first step
  /// does not, because the form itself is already sliding up.
  bool _stepChanged = false;

  @override
  void didUpdateWidget(StepScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.step != oldWidget.step) _stepChanged = true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final StepScaffold(:title, :subtitle, :step, :total, :stepName, :child, :nextLabel, :onNext, :onBack, :statusBar, :busy) =
        widget;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CurvedHeader(
            title: title,
            subtitle: subtitle,
            close: true,
            actions: [?statusBar],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.stepOf(step, total, stepName),
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
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
                          // The next segment fills as the step changes.
                          child: AnimatedContainer(
                            duration: AppMotion.of(context, AppMotion.medium),
                            curve: AppMotion.standard,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i <= step ? Colors.white : Colors.white.withValues(alpha: 0.3),
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
          Expanded(
            child: _stepChanged ? EnterTransition(key: ValueKey(step), child: child) : child,
          ),
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

/// Large buttons for one choice among a few (final design screens 15–18), for
/// example yes / no or normal / markedly reduced / absent. The chosen one is
/// filled; [danger] fills a chosen value in red (a "yes" danger sign).
class ChoiceButtons<T> extends StatelessWidget {
  const ChoiceButtons({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.danger = const {},
  });

  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  /// Values shown in red when chosen.
  final Set<T> danger;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, (value, label)) in options.indexed) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              selected: value == selected,
              button: true,
              child: OutlinedButton(
                onPressed: () => onSelected(value),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  backgroundColor: value != selected
                      ? AppColors.surface
                      : danger.contains(value)
                      ? AppColors.statusProblem
                      : AppColors.primarySoft,
                  foregroundColor: value != selected
                      ? AppColors.text
                      : danger.contains(value)
                      ? Colors.white
                      : AppColors.primaryDark,
                  side: BorderSide(
                    color: value != selected
                        ? AppColors.fieldBorder
                        : danger.contains(value)
                        ? AppColors.statusProblem
                        : AppColors.primary,
                    width: value == selected ? 2 : 1,
                  ),
                ),
                child: Text(label, textAlign: TextAlign.center),
              ),
            ),
          ),
        ],
      ],
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
