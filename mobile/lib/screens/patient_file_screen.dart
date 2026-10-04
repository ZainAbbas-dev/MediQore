// M2 FE-1, FE-2, FE-3: a woman's digital pregnancy file, from the phone. Her
// details, her home and its location, the current pregnancy and the obstetric
// history captured at registration. A home saved without GPS can get its
// location here later.
// M3 FE-1: a new visit starts here, and the pregnancy's visits are listed with
// whether each has reached the server or is held for the supervisor (FE-2).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../app_services.dart';
import '../data/app_database.dart';
import '../data/patient_repository.dart';
import '../data/visit_repository.dart';
import '../l10n/app_localizations.dart';
import '../location/location_service.dart';
import '../widgets/gps_capture.dart';
import '../widgets/large_button.dart';
import '../widgets/sync_status_text.dart';
import 'visit_screen.dart';

class PatientFileScreen extends StatefulWidget {
  const PatientFileScreen({super.key, required this.services, required this.womanId});

  final AppServices services;
  final String womanId;

  @override
  State<PatientFileScreen> createState() => _PatientFileScreenState();
}

class _PatientFileScreenState extends State<PatientFileScreen> {
  PatientFile? _file;
  List<VisitSummary> _visits = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final file = await widget.services.patients.file(widget.womanId);
    final pregnancy = file?.pregnancy;
    final visits = pregnancy == null ? const <VisitSummary>[] : await widget.services.visits.forPregnancy(pregnancy.id);
    if (mounted) {
      setState(() {
        _file = file;
        _visits = visits;
      });
    }
  }

  Future<void> _newVisit(PatientFile file, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.of(context).push<LocalVisit>(
      MaterialPageRoute(
        builder: (_) => VisitScreen(
          services: widget.services,
          pregnancyId: file.pregnancy!.id,
          title: '${file.woman.name} · ${file.woman.patientCode}',
        ),
      ),
    );
    if (saved == null || !mounted) return;
    await _load();
    messenger.showSnackBar(SnackBar(content: Text(l10n.visitSaved)));
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
          if (syncStatusText(l10n, file.syncStatus) case final status?)
            Text(
              status,
              style: TextStyle(color: file.syncStatus == SyncStatus.refused ? theme.colorScheme.error : null),
            ),
          if (pregnancy != null && pregnancy.status == 'active') ...[
            const SizedBox(height: 16),
            LargeButton(label: l10n.fileNewVisitButton, icon: Icons.add, onPressed: () => _newVisit(file, l10n)),
          ],
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
            section(l10n.fileVisitsSection),
            if (_visits.isEmpty)
              Text(l10n.fileNoVisits, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline))
            else
              for (final visit in _visits) _VisitCard(visit),
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

/// One visit: when it was, its readings, the signs recorded and its sync state.
class _VisitCard extends StatelessWidget {
  const _VisitCard(this.summary);

  final VisitSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final v = summary.visit;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final status = syncStatusText(l10n, summary.syncStatus);

    String number(double value) => value == value.roundToDouble() ? '${value.toInt()}' : '$value';
    final readings = [
      if (v.systolicBpMmhg != null && v.diastolicBpMmhg != null)
        (l10n.visitBloodPressure, '${v.systolicBpMmhg}/${v.diastolicBpMmhg} ${l10n.unitMmHg}'),
      if (v.weightKg != null) (l10n.fieldWeight, '${number(v.weightKg!)} ${l10n.unitKg}'),
      if (v.temperatureC != null) (l10n.fieldTemperature, '${number(v.temperatureC!)} ${l10n.unitCelsius}'),
      if (v.pulseBpm != null) (l10n.fieldPulse, '${v.pulseBpm} ${l10n.unitPerMinute}'),
      if (v.bloodSugarMmolL != null) (l10n.fieldBloodSugar, '${number(v.bloodSugarMmolL!)} ${l10n.unitMmolL}'),
    ];
    final signs = [
      if (v.fetalMovement case final movement?)
        '${l10n.fieldFetalMovement}: ${switch (movement) {
          'reduced' => l10n.fetalMovementReduced,
          'absent' => l10n.fetalMovementAbsent,
          _ => l10n.fetalMovementNormal,
        }}',
      if (v.swelling) l10n.fieldSwelling,
      if (v.bleeding) l10n.fieldBleeding,
      if (v.fever) l10n.fieldFever,
      if (v.urineSymptoms) l10n.fieldUrineSymptoms,
      if (v.anaemiaSigns != 'none')
        '${l10n.fieldAnaemia}: ${v.anaemiaSigns == 'severe' ? l10n.anaemiaSevere : l10n.anaemiaPresent}',
    ];

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The phone's clock, shown as it is; never used to order visits (LI-7).
            Text(DateFormat.yMMMMd(locale).add_jm().format(v.visitedAt.toLocal()), style: theme.textTheme.titleMedium),
            if (status != null)
              Text(
                status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: summary.syncStatus == SyncStatus.refused ? theme.colorScheme.error : null,
                ),
              ),
            for (final (label, value) in readings)
              Wrap(
                spacing: 8,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  Text(value, textDirection: TextDirection.ltr, style: theme.textTheme.bodyLarge),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              '${l10n.visitSigns}: ${signs.isEmpty ? l10n.visitNoSigns : signs.join(l10n.listSeparator)}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
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
