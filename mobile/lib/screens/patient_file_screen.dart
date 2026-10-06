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
import '../theme/app_colors.dart';
import '../widgets/app_cards.dart';
import '../widgets/gps_capture.dart';
import '../widgets/large_button.dart';
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
      return Scaffold(
        appBar: AppBar(title: Text(l10n.fileTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final woman = file.woman;
    final household = file.household;
    final pregnancy = file.pregnancy;
    final history = file.history;
    final dateFormat = DateFormat.yMMMMd(Localizations.localeOf(context).toLanguageTag());

    const gap = SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.fileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  InitialAvatar(woman.name, radius: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(woman.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                        Text(l10n.patientIdLabel, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
                        Text(woman.patientCode, textDirection: TextDirection.ltr, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        SyncStatusChip(file.syncStatus),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (pregnancy != null && pregnancy.status == 'active') ...[
            gap,
            LargeButton(label: l10n.fileNewVisitButton, icon: Icons.add, onPressed: () => _newVisit(file, l10n)),
          ],
          gap,
          SectionCard(
            title: l10n.regWomanSection,
            icon: Icons.person,
            children: [
              InfoRow(l10n.regAge, woman.age?.toString(), ltr: true),
              InfoRow(l10n.regHusbandName, woman.husbandName),
              InfoRow(l10n.regContactNumber, woman.contactNumber, ltr: true),
            ],
          ),
          gap,
          SectionCard(
            title: l10n.regHomeSection,
            icon: Icons.home,
            children: [
              InfoRow(l10n.regVillage, household?.village),
              InfoRow(l10n.regAddress, household?.address),
              if (household?.latitude != null && household?.longitude != null)
                InfoRow(l10n.gpsLabel, '${household!.latitude!.toStringAsFixed(6)}, ${household.longitude!.toStringAsFixed(6)}', ltr: true)
              else if (household != null)
                GpsCapture(location: widget.services.location, onCaptured: (fix) => _saveLocation(fix, l10n)),
            ],
          ),
          if (pregnancy != null) ...[
            gap,
            SectionCard(
              title: l10n.regPregnancySection,
              icon: Icons.pregnant_woman,
              children: [
                InfoRow(l10n.fileRegisteredOn, _formatDate(dateFormat, pregnancy.registeredOn)),
                InfoRow(l10n.fileMonthAtRegistration, '${pregnancy.pregnancyMonthAtRegistration}', ltr: true),
                InfoRow(l10n.fileStatus, pregnancy.status == 'active' ? l10n.fileStatusActive : l10n.fileStatusClosed),
              ],
            ),
            gap,
            SectionCard(
              title: l10n.fileVisitsSection,
              icon: Icons.event_note,
              children: [
                if (_visits.isEmpty)
                  Text(l10n.fileNoVisits, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline))
                else
                  for (final visit in _visits) _VisitCard(visit),
              ],
            ),
          ],
          if (history != null) ...[
            gap,
            SectionCard(
              title: l10n.regHistorySection,
              icon: Icons.history,
              children: [
                InfoRow(l10n.regPreviousPregnancies, '${history.previousPregnancies}', ltr: true),
                InfoRow(l10n.regPreviousCSections, '${history.previousCSections}', ltr: true),
                InfoRow(l10n.regStillbirths, '${history.stillbirths}', ltr: true),
                InfoRow(l10n.regKnownConditions, history.knownConditions),
              ],
            ),
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
      if (v.anaemiaSigns != 'none') '${l10n.fieldAnaemia}: ${v.anaemiaSigns == 'severe' ? l10n.anaemiaSevere : l10n.anaemiaPresent}',
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The phone's clock, shown as it is; never used to order visits (LI-7).
            Text(
              DateFormat.yMMMMd(locale).add_jm().format(v.visitedAt.toLocal()),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Align(alignment: AlignmentDirectional.centerStart, child: SyncStatusChip(summary.syncStatus)),
            const SizedBox(height: 8),
            for (final (label, value) in readings)
              Padding(padding: const EdgeInsets.only(bottom: 4), child: InfoRow(label, value, ltr: true)),
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
