// M2 FE-1: after saving a registration, the new patient ID and the reassurance
// that the record is on the phone and will sync later (P0-7 screen 3).
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/app_database.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_cards.dart';
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
    void replaceWith(Widget screen) => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => screen));

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Final design 12: a teal success header with the card over its edge.
          Material(
            color: AppColors.primary,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.headerRadius)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 28 + _overlap),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.check_rounded, size: 52, color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.savedTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -_overlap),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            woman.name,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(l10n.patientIdLabel, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
                          const SizedBox(height: 6),
                          DecoratedBox(
                            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              // One line on any phone: the ID is never broken at its hyphens.
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  woman.patientCode,
                                  textDirection: TextDirection.ltr,
                                  maxLines: 1,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: AppColors.primaryDark,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          NoticeCard(text: l10n.savedOnPhone, icon: Icons.phone_android, tone: NoticeTone.success),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(minimumSize: const Size.fromHeight(AppTheme.largeControlHeight)),
                    icon: const Icon(Icons.home_outlined),
                    label: Text(l10n.savedDone, style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// How far the card reaches over the header.
  static const double _overlap = 40;
}
