// M2 FE-1, FE-2, FE-3: a woman's digital pregnancy file, from the phone. Her
// details, her home and its location, the current pregnancy and the obstetric
// history captured at registration. A home saved without GPS can get its
// location here later. Visits (M3) are added to this file in their module.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../app_services.dart';
import '../data/patient_repository.dart';
import '../l10n/app_localizations.dart';
import '../location/location_service.dart';
import '../widgets/gps_capture.dart';

class PatientFileScreen extends StatefulWidget {
  const PatientFileScreen({super.key, required this.services, required this.womanId});

  final AppServices services;
  final String womanId;

  @override
  State<PatientFileScreen> createState() => _PatientFileScreenState();
}

class _PatientFileScreenState extends State<PatientFileScreen> {
  PatientFile? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final file = await widget.services.patients.file(widget.womanId);
    if (mounted) setState(() => _file = file);
  }

  Future<void> _saveLocation(LocationFix fix, AppLocalizations l10n) async {
    final householdId = _file?.household?.id;
    if (householdId == null) return;
    await widget.services.households.setLocation(householdId, latitude: fix.latitude, longitude: fix.longitude);
    await _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fileLocationSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final file = _file;
    if (file == null) {
      return Scaffold(appBar: AppBar(title: Text(l10n.fileTitle)), body: const Center(child: CircularProgressIndicator()));
    }

    final woman = file.woman;
    final household = file.household;
    final pregnancy = file.pregnancy;
    final history = file.history;
    final dateFormat = DateFormat.yMMMMd(Localizations.localeOf(context).toLanguageTag());

    Widget section(String title) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 4),
          child: Text(title, style: theme.textTheme.titleLarge),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.fileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(woman.name, style: theme.textTheme.headlineSmall),
          _Field(l10n.patientIdLabel, woman.patientCode, ltr: true),
          if (file.syncStatus != SyncStatus.synced)
            Text(
              file.syncStatus == SyncStatus.waiting ? l10n.syncWaiting : l10n.syncRefused,
              style: TextStyle(color: file.syncStatus == SyncStatus.refused ? theme.colorScheme.error : null),
            ),
          section(l10n.regWomanSection),
          _Field(l10n.regAge, woman.age?.toString(), ltr: true),
          _Field(l10n.regHusbandName, woman.husbandName),
          _Field(l10n.regContactNumber, woman.contactNumber, ltr: true),
          section(l10n.regHomeSection),
          _Field(l10n.regVillage, household?.village),
          _Field(l10n.regAddress, household?.address),
          if (household?.latitude != null && household?.longitude != null)
            _Field(
              l10n.gpsLabel,
              '${household!.latitude!.toStringAsFixed(6)}, ${household.longitude!.toStringAsFixed(6)}',
              ltr: true,
            )
          else if (household != null) ...[
            const SizedBox(height: 8),
            GpsCapture(location: widget.services.location, onCaptured: (fix) => _saveLocation(fix, l10n)),
          ],
          if (pregnancy != null) ...[
            section(l10n.regPregnancySection),
            _Field(l10n.fileRegisteredOn, _formatDate(dateFormat, pregnancy.registeredOn)),
            _Field(l10n.fileMonthAtRegistration, '${pregnancy.pregnancyMonthAtRegistration}', ltr: true),
            _Field(l10n.fileStatus, pregnancy.status == 'active' ? l10n.fileStatusActive : l10n.fileStatusClosed),
          ],
          if (history != null) ...[
            section(l10n.regHistorySection),
            _Field(l10n.regPreviousPregnancies, '${history.previousPregnancies}', ltr: true),
            _Field(l10n.regPreviousCSections, '${history.previousCSections}', ltr: true),
            _Field(l10n.regStillbirths, '${history.stillbirths}', ltr: true),
            _Field(l10n.regKnownConditions, history.knownConditions),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateFormat format, String date) {
    final parsed = DateTime.tryParse(date);
    return parsed == null ? date : format.format(parsed);
  }
}

/// A label with its value below it; an empty value says "not recorded".
class _Field extends StatelessWidget {
  const _Field(this.label, this.value, {this.ltr = false});

  final String label;
  final String? value;

  /// IDs, numbers and coordinates read left to right in both languages.
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final empty = value == null || value!.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      // Start-aligned, so a left-to-right value sits under its label in Urdu too.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            empty ? l10n.fileNotRecorded : value!,
            textDirection: !empty && ltr ? TextDirection.ltr : null,
            style: theme.textTheme.bodyLarge?.copyWith(color: empty ? theme.colorScheme.outline : null),
          ),
        ],
      ),
    );
  }
}
