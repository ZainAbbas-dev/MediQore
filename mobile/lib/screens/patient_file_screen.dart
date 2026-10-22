// M2 FE-1, FE-2, FE-3: a woman's digital pregnancy file, from the phone (final
// design screen 14). Her details, her home and its location, the current
// pregnancy and the obstetric history captured at registration, with the
// risk-factor flags the Clinical Rules Table finds in it (they never change the
// risk colour unless the signed table says so). A home saved without GPS can
// get its location here later.
// M3 FE-1: a new visit starts here, and the pregnancy's visits are listed with
// whether each has reached the server or is held for the supervisor (FE-2).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../app_services.dart';
import '../clinical/clinical_rules.dart';
import '../data/app_database.dart';
import '../data/patient_repository.dart';
import '../data/visit_repository.dart';
import '../l10n/app_localizations.dart';
import '../location/location_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_cards.dart';
import '../widgets/curved_header.dart';
import '../widgets/gps_capture.dart';
import '../widgets/large_button.dart';
import 'visit_screen.dart';
import '../theme/app_motion.dart';

class PatientFileScreen extends StatefulWidget {
  const PatientFileScreen({super.key, required this.services, required this.womanId});

  final AppServices services;
  final String womanId;

  @override
  State<PatientFileScreen> createState() => _PatientFileScreenState();
}

/// The words for an obstetric history flag of the Clinical Rules Table; a flag
/// added to the table later shows its ID until it gets its words.
String obstetricFlagText(AppLocalizations l10n, String id) => switch (id) {
  'previous_c_section' => l10n.flagPreviousCSection,
  'previous_stillbirth' => l10n.flagPreviousStillbirth,
  'grand_multiparity' => l10n.flagGrandMultiparity,
  'known_medical_condition' => l10n.flagKnownMedicalCondition,
  'adolescent_pregnancy' => l10n.flagAdolescentPregnancy,
  'advanced_maternal_age' => l10n.flagAdvancedMaternalAge,
  _ => id,
};

class _PatientFileScreenState extends State<PatientFileScreen> {
  PatientFile? _file;
  List<VisitSummary> _visits = const [];
  ClinicalRules? _rules;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _rules ??= widget.services.clinicalRules ?? await ClinicalRules.load();
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

  Future<void> _newVisit(PatientFile file, AppLocalizations l10n, {int? weeksToday}) async {
    final messenger = ScaffoldMessenger.of(context);
    final from = _rules?.fetalMovementFromWeeks;
    final saved = await Navigator.of(context).push<LocalVisit>(
      AppRoutes.form(
        VisitScreen(
          services: widget.services,
          pregnancyId: file.pregnancy!.id,
          title: '${file.woman.name} · ${file.woman.patientCode}',
          fetalMovementFromWeeks: from != null && weeksToday != null && weeksToday < from ? from : null,
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
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CurvedHeader(title: l10n.fileTitle),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      );
    }

    final woman = file.woman;
    final household = file.household;
    final pregnancy = file.pregnancy;
    final history = file.history;
    final dateFormat = DateFormat.yMMMMd(Localizations.localeOf(context).toLanguageTag());

    const gap = SizedBox(height: 12);

    final rules = _rules;
    // M2 FE-1: the estimated delivery date and today's gestational age.
    final edd = rules == null || pregnancy == null
        ? null
        : rules.gestationalAge.eddOf(
            estimatedDeliveryDate: pregnancy.estimatedDeliveryDate,
            registeredOn: pregnancy.registeredOn,
            month: pregnancy.pregnancyMonthAtRegistration,
          );
    final weeksToday = edd == null || pregnancy?.status != 'active'
        ? null
        : rules!.gestationalAge.completedWeeksOn(edd, DateTime.now());
    final flags = rules == null || history == null
        ? const <String>[]
        : rules.obstetricFlags({
            'age': woman.age,
            'previousPregnancies': history.previousPregnancies,
            'previousCSections': history.previousCSections,
            'stillbirths': history.stillbirths,
            'knownConditions': history.knownConditions,
          });
    final white = theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9));

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          CurvedHeader(
            title: l10n.fileTitle,
            overlap: 40,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  child: Text(
                    woman.name.trim().isEmpty ? '?' : woman.name.trim().characters.first.toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        woman.name,
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      Text(woman.patientCode, textDirection: TextDirection.ltr, style: white),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      _Stat(woman.age?.toString() ?? '–', l10n.fileStatAge),
                      _Stat(weeksToday == null ? '–' : '$weeksToday', l10n.fileStatWeeks),
                      _Stat('${_visits.length}', l10n.fileStatVisits),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: AlignmentDirectional.centerStart, child: SyncStatusChip(file.syncStatus)),
                if (pregnancy != null && pregnancy.status == 'active') ...[
                  gap,
                  LargeButton(label: l10n.fileNewVisitButton, icon: Icons.add, onPressed: () => _newVisit(file, l10n, weeksToday: weeksToday)),
                ],
                if (pregnancy != null) ...[
                  gap,
                  SectionCard(
                    title: l10n.fileVisitsSection,
                    icon: Icons.event_note_outlined,
                    children: [
                      if (_visits.isEmpty)
                        EmptyNote(text: l10n.fileNoVisits, icon: Icons.event_busy_outlined)
                      else
                        for (final visit in _visits) _VisitCard(visit),
                    ],
                  ),
                ],
                if (history != null && rules != null) ...[
                  gap,
                  SectionCard(
                    title: l10n.fileRiskFactors,
                    icon: Icons.flag_outlined,
                    children: [
                      if (flags.isEmpty)
                        Text(l10n.fileNoRiskFactors, style: theme.textTheme.bodyLarge)
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final flag in flags)
                              StatusPill(
                                label: obstetricFlagText(l10n, flag),
                                icon: Icons.flag,
                                foreground: AppColors.statusPending,
                                background: AppColors.statusPendingBackground,
                              ),
                          ],
                        ),
                      Text(
                        rules.status == 'pending clinical review'
                            ? l10n.fileRiskFactorsPending(rules.version)
                            : l10n.fileRiskFactorsSigned(rules.version),
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                      ),
                    ],
                  ),
                ],
                gap,
                SectionCard(
                  title: l10n.regWomanSection,
                  icon: Icons.person_outline,
                  children: [
                    InfoRow(l10n.regAge, woman.age?.toString(), ltr: true),
                    InfoRow(l10n.regHusbandName, woman.husbandName),
                    InfoRow(l10n.regContactNumber, woman.contactNumber, ltr: true),
                  ],
                ),
                gap,
                SectionCard(
                  title: l10n.regHomeSection,
                  icon: Icons.home_outlined,
                  children: [
                    InfoRow(l10n.regVillage, household?.village),
                    InfoRow(l10n.regAddress, household?.address),
                    if (household?.latitude != null && household?.longitude != null)
                      InfoRow(
                        l10n.gpsLabel,
                        '${household!.latitude!.toStringAsFixed(6)}, ${household.longitude!.toStringAsFixed(6)}',
                        ltr: true,
                      )
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
                      if (edd != null)
                        InfoRow(
                          l10n.fileEdd,
                          '${dateFormat.format(edd)} · ${switch (pregnancy.eddBasis) {
                            'lmp' => l10n.fileEddFromLmp(_formatDate(dateFormat, pregnancy.lmpDate!)),
                            'edd' => l10n.fileEddFromCard,
                            _ => l10n.fileEddFromMonth,
                          }}',
                        ),
                      InfoRow(
                        l10n.fileStatus,
                        pregnancy.status == 'active' ? l10n.fileStatusActive : l10n.fileStatusClosed,
                      ),
                    ],
                  ),
                ],
                if (history != null) ...[
                  gap,
                  SectionCard(
                    title: l10n.regHistorySection,
                    icon: Icons.history_outlined,
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
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateFormat format, String date) {
    final parsed = DateTime.tryParse(date);
    return parsed == null ? date : format.format(parsed);
  }
}

/// A number and its label in the stats card under the header.
class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
          ),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
        ],
      ),
    );
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
        (Icons.favorite_border, l10n.visitBloodPressure, '${v.systolicBpMmhg}/${v.diastolicBpMmhg} ${l10n.unitMmHg}'),
      if (v.weightKg != null) (Icons.monitor_weight_outlined, l10n.fieldWeight, '${number(v.weightKg!)} ${l10n.unitKg}'),
      if (v.temperatureC != null)
        (Icons.thermostat, l10n.fieldTemperature, '${number(v.temperatureC!)} ${l10n.unitCelsius}'),
      if (v.pulseBpm != null) (Icons.monitor_heart_outlined, l10n.fieldPulse, '${v.pulseBpm} ${l10n.unitPerMinute}'),
      if (v.bloodSugarValue != null)
        (
          Icons.water_drop_outlined,
          l10n.fieldBloodSugar,
          [
            '${number(v.bloodSugarValue!)} ${v.bloodSugarUnit == 'mg_dl' ? l10n.unitMgDl : l10n.unitMmolL}',
            if (v.bloodSugarSource == 'lab_report') l10n.sugarSourceLab,
            if (v.bloodSugarSource == 'glucometer') l10n.sugarSourceGlucometer,
            ?v.bloodSugarMeasuredOn,
          ].join(' · '),
        ),
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
    // The danger signs answered "yes" (M3 FE-1).
    final danger = [
      for (final (sign, answer) in [
        ('convulsions', v.convulsions),
        ('severeHeadache', v.severeHeadache),
        ('blurredVision', v.blurredVision),
        ('severeAbdominalPain', v.severeAbdominalPain),
        ('fastBreathing', v.fastBreathing),
        ('feverWithWeakness', v.feverWithWeakness),
      ])
        if (answer == true) dangerSignLabel(l10n, sign).$1,
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: danger.isEmpty ? AppColors.border : AppColors.statusProblem, width: danger.isEmpty ? 1 : 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                // The phone's clock, shown as it is; never used to order visits (LI-7).
                Text(
                  DateFormat.yMMMMd(locale).add_Hm().format(v.visitedAt.toLocal()),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                SyncStatusChip(summary.syncStatus),
              ],
            ),
            const SizedBox(height: 8),
            // Each reading with its icon; the unit tells which one it is.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final (icon, label, value) in readings) _Reading(icon: icon, label: label, value: value)],
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.visitSigns}: ${signs.isEmpty ? l10n.visitNoSigns : signs.join(l10n.listSeparator)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (danger.isNotEmpty) ...[
              const SizedBox(height: 8),
              NoticeCard(
                text: '${l10n.visitStepDanger}: ${danger.join(l10n.listSeparator)}',
                tone: NoticeTone.problem,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One reading of a visit as a small white chip: its icon and value, with the
/// reading's name for screen readers.
class _Reading extends StatelessWidget {
  const _Reading({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
