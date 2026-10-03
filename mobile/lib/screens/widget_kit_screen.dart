import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/form_fields.dart';
import '../widgets/large_button.dart';
import '../widgets/offline_status_bar.dart';
import '../widgets/risk_chip.dart';

/// Preview of the shared widget kit (P0-2), so the Urdu rendering, RTL layout
/// and control sizes can be checked on a real phone. The login screen replaces
/// it as the home screen in Phase 1.
class WidgetKitScreen extends StatefulWidget {
  const WidgetKitScreen({super.key});

  @override
  State<WidgetKitScreen> createState() => _WidgetKitScreenState();
}

enum _FetalMovement { normal, reduced, absent }

class _WidgetKitScreenState extends State<WidgetKitScreen> {
  bool _bleeding = false;
  _FetalMovement? _fetalMovement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final headingStyle = Theme.of(context).textTheme.titleLarge;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.kitTitle)),
      body: Column(
        children: [
          const OfflineStatusBar(isOnline: false),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.kitButtonsSection, style: headingStyle),
                const SizedBox(height: 8),
                LargeButton(label: l10n.kitSaveButton, icon: Icons.save, onPressed: () {}),
                const SizedBox(height: 12),
                LargeButton(label: l10n.kitCancelButton, secondary: true, onPressed: () {}),
                const SizedBox(height: 24),
                Text(l10n.kitFormSection, style: headingStyle),
                const SizedBox(height: 8),
                AppTextField(label: l10n.fieldName),
                const SizedBox(height: 16),
                VitalField(label: l10n.fieldSystolicBp, unit: l10n.unitMmHg),
                const SizedBox(height: 8),
                CheckboxField(
                  label: l10n.fieldBleeding,
                  value: _bleeding,
                  onChanged: (value) => setState(() => _bleeding = value),
                ),
                const SizedBox(height: 8),
                DropdownField<_FetalMovement>(
                  label: l10n.fieldFetalMovement,
                  value: _fetalMovement,
                  onChanged: (value) => setState(() => _fetalMovement = value),
                  options: [
                    DropdownOption(_FetalMovement.normal, l10n.fetalMovementNormal),
                    DropdownOption(_FetalMovement.reduced, l10n.fetalMovementReduced),
                    DropdownOption(_FetalMovement.absent, l10n.fetalMovementAbsent),
                  ],
                ),
                const SizedBox(height: 24),
                Text(l10n.kitRiskSection, style: headingStyle),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    RiskChip(level: RiskLevel.green),
                    RiskChip(level: RiskLevel.yellow),
                    RiskChip(level: RiskLevel.red),
                  ],
                ),
                const SizedBox(height: 16),
                const OfflineStatusBar(isOnline: true, pendingCount: 3),
                const SizedBox(height: 8),
                const OfflineStatusBar(isOnline: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
