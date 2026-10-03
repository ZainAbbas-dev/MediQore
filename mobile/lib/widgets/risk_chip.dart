import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Risk levels shown to the LHW (M4): the final level after the model and the
/// danger-sign rules.
enum RiskLevel { green, yellow, red }

/// Colour-coded risk label. It always shows an icon and text as well as the
/// colour, so the level never depends on colour alone.
class RiskChip extends StatelessWidget {
  const RiskChip({super.key, required this.level});

  final RiskLevel level;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (background, foreground, icon, label) = switch (level) {
      RiskLevel.green => (AppColors.riskGreen, AppColors.onRiskGreen, Icons.check_circle, l10n.riskGreen),
      RiskLevel.yellow => (AppColors.riskYellow, AppColors.onRiskYellow, Icons.warning_amber_rounded, l10n.riskYellow),
      RiskLevel.red => (AppColors.riskRed, AppColors.onRiskRed, Icons.error, l10n.riskRed),
    };

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 24),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}
