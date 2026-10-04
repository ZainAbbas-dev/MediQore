// M2 FE-1: after saving a registration, the new patient ID and the reassurance
// that the record is on the phone and will sync later (P0-7 screen 3).
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/app_database.dart';
import '../l10n/app_localizations.dart';
import '../widgets/large_button.dart';
import 'patient_file_screen.dart';
import 'register_screen.dart';

class RegistrationSavedScreen extends StatelessWidget {
  const RegistrationSavedScreen({super.key, required this.services, required this.woman});

  final AppServices services;
  final LocalWoman woman;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    void replaceWith(Widget screen) =>
        Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.savedTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(Icons.check_circle, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(woman.name, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(l10n.patientIdLabel, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          Text(
            woman.patientCode,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(l10n.savedOnPhone, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          LargeButton(
            label: l10n.savedOpenFile,
            icon: Icons.folder_open,
            onPressed: () => replaceWith(PatientFileScreen(services: services, womanId: woman.id)),
          ),
          const SizedBox(height: 12),
          LargeButton(
            label: l10n.savedRegisterAnother,
            icon: Icons.person_add,
            secondary: true,
            onPressed: () => replaceWith(RegisterScreen(services: services)),
          ),
          const SizedBox(height: 12),
          LargeButton(label: l10n.savedDone, icon: Icons.done, secondary: true, onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}
