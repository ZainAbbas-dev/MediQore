// M3 FE-1: the home visit, a three-step form (final design screens 15–19,
// scope Mockup 2), saved on the phone with no internet needed.
// 1. Measurements: BP, weight, temperature, the required pulse (from the BP
//    device, or the 30-second counter) and an optional blood sugar with its
//    unit (stored in mmol/L), source and date.
// 2. Signs: fetal movement, anaemia signs, swelling, bleeding, fever, urine.
// 3. The yes/no danger-sign checklist with pictures; every question needs an
//    answer, and a "yes" turns the card red.
// Impossible values cannot be saved; values outside the usual range are kept
// only after the LHW confirms them. Every range, the pulse counter and the
// mg/dL factor come from the Clinical Rules Table (assets/clinical/clinical-rules.json).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../app_services.dart';
import '../clinical/visit_ranges.dart';
import '../data/app_database.dart';
import '../data/patient_repository.dart';
import '../data/visit_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/form_fields.dart';
import '../widgets/offline_status_bar.dart';
import '../widgets/step_scaffold.dart';
import 'pulse_counter_screen.dart';

/// A value outside its usual range, for the confirmation dialog.
class _Unusual {
  const _Unusual(this.label, this.value, this.unit, this.range);

  final String label;
  final String value;
  final String unit;

  /// The usual range, in [unit].
  final (num, num) range;
}

/// The danger-sign checklist questions, by their sync field names (M4 FE-4).
const List<String> dangerSigns = [
  'convulsions',
  'severeHeadache',
  'blurredVision',
  'severeAbdominalPain',
  'fastBreathing',
  'feverWithWeakness',
];

/// The words and the picture of a danger sign.
(String, IconData) dangerSignLabel(AppLocalizations l10n, String sign) => switch (sign) {
  'convulsions' => (l10n.dangerConvulsions, Icons.flash_on),
  'severeHeadache' => (l10n.dangerSevereHeadache, Icons.sick_outlined),
  'blurredVision' => (l10n.dangerBlurredVision, Icons.visibility_off_outlined),
  'severeAbdominalPain' => (l10n.dangerAbdominalPain, Icons.pregnant_woman),
  'fastBreathing' => (l10n.dangerBreathing, Icons.air),
  _ => (l10n.dangerFeverWeakness, Icons.thermostat),
};

class VisitScreen extends StatefulWidget {
  /// Records a visit for [pregnancyId]. The range checks are [ranges], or the
  /// ones the app read at start, or else read now from the config file. Closes
  /// with the saved visit.
  const VisitScreen({super.key, required this.services, required this.pregnancyId, required this.title, this.ranges});

  final AppServices services;
  final String pregnancyId;

  /// The woman's name and patient ID, shown at the top.
  final String title;
  final VisitRanges? ranges;

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  static const int _steps = 3;
  final _measurements = GlobalKey<FormState>();
  int _step = 0;

  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _weight = TextEditingController();
  final _temperature = TextEditingController();
  final _pulse = TextEditingController();
  final _sugar = TextEditingController();

  bool _sugarInMgDl = false;
  String? _sugarSource;
  late DateTime _sugarDate = _today();

  String? _fetalMovement;
  String _anaemia = 'none';
  bool _swelling = false;
  bool _bleeding = false;
  bool _fever = false;
  bool _urine = false;

  final Map<String, bool?> _danger = {for (final sign in dangerSigns) sign: null};
  bool _showUnanswered = false;

  VisitRanges? _ranges;
  bool _saving = false;

  AppServices get _services => widget.services;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _ranges = widget.ranges ?? _services.visitRanges;
    if (_ranges == null) {
      VisitRanges.load().then((ranges) {
        if (mounted) setState(() => _ranges = ranges);
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_systolic, _diastolic, _weight, _temperature, _pulse, _sugar]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _number(num n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';

  // The blood sugar range in the unit the LHW is typing.
  (num, num) _sugarRange((num, num) mmolL) =>
      _sugarInMgDl ? ((mmolL.$1 * _ranges!.mgDlPerMmolL).ceil(), (mmolL.$2 * _ranges!.mgDlPerMmolL).floor()) : mmolL;

  // Required, then possible (inside what the server accepts).
  FormFieldValidator<String> _vital(String field, AppLocalizations l10n, {bool required = true}) => (text) {
    final value = num.tryParse((text ?? '').trim());
    if ((text ?? '').trim().isEmpty) return required ? l10n.regErrorRequired : null;
    final range = _ranges![field];
    final (min, max) = field == 'bloodSugarMmolL' ? _sugarRange(range.allowed) : range.allowed;
    if (value == null || value < min || value > max) {
      return l10n.visitErrorNotPossible(_number(min), _number(max));
    }
    return null;
  };

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());
  double? _double(TextEditingController c) => double.tryParse(c.text.trim());

  /// The blood sugar in mmol/L, as it is stored, or null.
  double? get _sugarMmolL {
    final typed = _double(_sugar);
    if (typed == null) return null;
    return _sugarInMgDl ? _ranges!.mmolLFromMgDl(typed) : typed;
  }

  Future<void> _countPulse() async {
    final ranges = _ranges!;
    final pulse = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => PulseCounterScreen(seconds: ranges.pulseCountSeconds, multiplier: ranges.pulseMultiplier),
      ),
    );
    if (pulse != null && mounted) setState(() => _pulse.text = '$pulse');
  }

  Future<void> _pickSugarDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _sugarDate,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _sugarDate = picked);
  }

  Future<void> _next(AppLocalizations l10n) async {
    switch (_step) {
      case 0:
        if (!_measurements.currentState!.validate()) return;
        if (!await _confirmUnusual(l10n)) return;
        setState(() => _step = 1);
      case 1:
        setState(() => _step = 2);
      default:
        if (_danger.values.any((answer) => answer == null)) {
          setState(() => _showUnanswered = true);
          return;
        }
        await _save();
    }
  }

  // M3 FE-1: a value outside the usual range may be a typing error. It is
  // kept only if the LHW confirms it.
  Future<bool> _confirmUnusual(AppLocalizations l10n) async {
    final ranges = _ranges!;
    final sugarUnit = _sugarInMgDl ? l10n.unitMgDl : l10n.unitMmolL;
    final unusual = <_Unusual>[
      for (final (field, label, controller, unit) in [
        ('systolicBpMmhg', l10n.fieldSystolicBp, _systolic, l10n.unitMmHg),
        ('diastolicBpMmhg', l10n.fieldDiastolicBp, _diastolic, l10n.unitMmHg),
        ('weightKg', l10n.fieldWeight, _weight, l10n.unitKg),
        ('temperatureC', l10n.fieldTemperature, _temperature, l10n.unitCelsius),
        ('pulseBpm', l10n.fieldPulse, _pulse, l10n.unitPerMinute),
      ])
        if (num.tryParse(controller.text.trim()) case final value? when !ranges[field].isPlausible(value))
          _Unusual(label, controller.text.trim(), unit, ranges[field].plausible),
      if (_sugarMmolL case final sugar? when !ranges['bloodSugarMmolL'].isPlausible(sugar))
        _Unusual(l10n.fieldBloodSugar, _sugar.text.trim(), sugarUnit, _sugarRange(ranges['bloodSugarMmolL'].plausible)),
    ];
    if (unusual.isEmpty) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(l10n.rangeCheckTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.rangeCheckIntro),
                for (final item in unusual) ...[
                  const SizedBox(height: 12),
                  Text(item.label, style: theme.textTheme.titleMedium),
                  // Numbers and units read left to right in both languages.
                  Text(
                    '${item.value} ${item.unit}',
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      Text(l10n.rangeCheckUsual),
                      Text(
                        '${_number(item.range.$1)}–${_number(item.range.$2)} ${item.unit}',
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.rangeCheckCorrect)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.rangeCheckConfirm)),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final sugar = _sugarMmolL;
    final LocalVisit visit;
    try {
      visit = await _services.visits.record(
        VisitInput(
          pregnancyId: widget.pregnancyId,
          systolicBpMmhg: _int(_systolic),
          diastolicBpMmhg: _int(_diastolic),
          weightKg: _double(_weight),
          temperatureC: _double(_temperature),
          pulseBpm: _int(_pulse),
          bloodSugarMmolL: sugar,
          bloodSugarEnteredUnit: sugar == null ? null : (_sugarInMgDl ? 'mg_dl' : 'mmol_l'),
          bloodSugarMeasuredOn: sugar == null ? null : PatientRepository.calendarDate(_sugarDate),
          bloodSugarSource: sugar == null ? null : _sugarSource,
          fetalMovement: _fetalMovement,
          swelling: _swelling,
          bleeding: _bleeding,
          fever: _fever,
          anaemiaSigns: _anaemia,
          urineSymptoms: _urine,
          convulsions: _danger['convulsions'],
          severeHeadache: _danger['severeHeadache'],
          blurredVision: _danger['blurredVision'],
          severeAbdominalPain: _danger['severeAbdominalPain'],
          fastBreathing: _danger['fastBreathing'],
          feverWithWeakness: _danger['feverWithWeakness'],
        ),
        by: _services.session.user!,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.of(context).pop(visit);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ranges = _ranges;
    if (ranges == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.visitTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final (name, content, nextLabel) = switch (_step) {
      0 => (l10n.visitVitalsSection, _measurementsStep(l10n, ranges), l10n.visitNextSigns),
      1 => (l10n.visitSymptomsSection, _signsStep(l10n), l10n.visitNextDanger),
      _ => (l10n.visitStepDanger, _dangerStep(l10n), l10n.visitSaveButton),
    };
    return StepScaffold(
      title: l10n.visitTitle,
      subtitle: widget.title,
      step: _step + 1,
      total: _steps,
      stepName: name,
      statusBar: LiveStatusBar(services: _services),
      busy: _saving,
      onBack: _step == 0 ? null : () => setState(() => _step--),
      nextLabel: nextLabel,
      onNext: () => _next(l10n),
      child: SingleChildScrollView(key: ValueKey(_step), padding: const EdgeInsets.all(16), child: content),
    );
  }

  Widget _pair(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ],
  );

  Widget _measurementsStep(AppLocalizations l10n, VisitRanges ranges) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: 12);
    final today = _today();
    final dateText = DateFormat('dd-MM-yyyy').format(_sugarDate);
    final sugarGiven = _sugar.text.trim().isNotEmpty;
    return Form(
      key: _measurements,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pair(
            VitalField(
              label: l10n.fieldSystolicBp,
              unit: l10n.unitMmHg,
              controller: _systolic,
              validator: _vital('systolicBpMmhg', l10n),
            ),
            VitalField(
              label: l10n.fieldDiastolicBp,
              unit: l10n.unitMmHg,
              controller: _diastolic,
              validator: (text) {
                final problem = _vital('diastolicBpMmhg', l10n)(text);
                if (problem != null) return problem;
                final systolic = _int(_systolic);
                return systolic != null && int.parse(text!.trim()) >= systolic ? l10n.visitErrorDiastolic : null;
              },
            ),
          ),
          gap,
          _pair(
            VitalField(
              label: l10n.fieldWeight,
              unit: l10n.unitKg,
              controller: _weight,
              decimals: ranges['weightKg'].decimals,
              validator: _vital('weightKg', l10n),
            ),
            VitalField(
              label: l10n.fieldTemperature,
              unit: l10n.unitCelsius,
              controller: _temperature,
              decimals: ranges['temperatureC'].decimals,
              validator: _vital('temperatureC', l10n),
            ),
          ),
          gap,
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  VitalField(
                    label: l10n.fieldPulse,
                    unit: l10n.unitPerMinute,
                    controller: _pulse,
                    validator: _vital('pulseBpm', l10n),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _countPulse,
                    icon: const Icon(Icons.timer_outlined),
                    label: Text(l10n.pulseCountButton(ranges.pulseCountSeconds)),
                  ),
                ],
              ),
            ),
          ),
          gap,
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: ChoiceButtons<bool>(
                      options: [(false, l10n.unitMmolL), (true, l10n.unitMgDl)],
                      selected: _sugarInMgDl,
                      onSelected: (mgDl) => setState(() => _sugarInMgDl = mgDl),
                    ),
                  ),
                  const SizedBox(height: 8),
                  VitalField(
                    key: ValueKey(_sugarInMgDl),
                    label: l10n.fieldBloodSugar,
                    unit: _sugarInMgDl ? l10n.unitMgDl : l10n.unitMmolL,
                    controller: _sugar,
                    decimals: _sugarInMgDl ? 0 : ranges['bloodSugarMmolL'].decimals,
                    validator: _vital('bloodSugarMmolL', l10n, required: false),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (sugarGiven) ...[
                    const SizedBox(height: 8),
                    ChoiceButtons<String>(
                      options: [('glucometer', l10n.sugarSourceGlucometer), ('lab_report', l10n.sugarSourceLab)],
                      selected: _sugarSource,
                      onSelected: (source) => setState(() => _sugarSource = source),
                    ),
                    FormField<void>(
                      validator: (_) => _sugarSource == null ? l10n.sugarErrorSource : null,
                      builder: (field) => field.hasError
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                field.errorText!,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.sugarMeasuredOn, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: _pickSugarDate,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      icon: const Icon(Icons.event),
                      label: Text(
                        _sugarDate == today ? l10n.sugarToday('\u2066$dateText\u2069') : '\u2066$dateText\u2069',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signsStep(AppLocalizations l10n) {
    final theme = Theme.of(context);
    Widget question(String label, Widget choices) => Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            choices,
          ],
        ),
      ),
    );
    Widget yesNo(String label, bool value, ValueChanged<bool> onChanged) => question(
      label,
      ChoiceButtons<bool>(
        options: [(true, l10n.answerYes), (false, l10n.answerNo)],
        selected: value,
        onSelected: onChanged,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        question(
          l10n.fieldFetalMovement,
          ChoiceButtons<String>(
            options: [
              ('normal', l10n.fetalMovementNormal),
              ('reduced', l10n.fetalMovementReduced),
              ('absent', l10n.fetalMovementAbsent),
            ],
            selected: _fetalMovement,
            // Pressing the chosen answer again clears it: not assessed (early pregnancy).
            onSelected: (value) => setState(() => _fetalMovement = value == _fetalMovement ? null : value),
          ),
        ),
        const SizedBox(height: 8),
        question(
          l10n.fieldAnaemia,
          ChoiceButtons<String>(
            options: [('none', l10n.anaemiaNone), ('present', l10n.anaemiaPresent), ('severe', l10n.anaemiaSevere)],
            selected: _anaemia,
            onSelected: (value) => setState(() => _anaemia = value),
          ),
        ),
        const SizedBox(height: 8),
        yesNo(l10n.fieldSwelling, _swelling, (v) => setState(() => _swelling = v)),
        const SizedBox(height: 8),
        yesNo(l10n.fieldBleeding, _bleeding, (v) => setState(() => _bleeding = v)),
        const SizedBox(height: 8),
        yesNo(l10n.fieldFever, _fever, (v) => setState(() => _fever = v)),
        const SizedBox(height: 8),
        yesNo(l10n.fieldUrineSymptoms, _urine, (v) => setState(() => _urine = v)),
      ],
    );
  }

  Widget _dangerStep(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.dangerAnswerAll, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
        const SizedBox(height: 8),
        for (final sign in dangerSigns) ...[
          _DangerCard(
            sign: sign,
            answer: _danger[sign],
            unanswered: _showUnanswered && _danger[sign] == null,
            onAnswer: (answer) => setState(() => _danger[sign] = answer),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          l10n.decisionSupportNote,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
        ),
      ],
    );
  }
}

/// One danger sign with its picture: a "yes" turns the card red.
class _DangerCard extends StatelessWidget {
  const _DangerCard({required this.sign, required this.answer, required this.unanswered, required this.onAnswer});

  final String sign;
  final bool? answer;
  final bool unanswered;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (label, icon) = dangerSignLabel(l10n, sign);
    final yes = answer == true;
    return Card(
      color: yes ? AppColors.statusProblemBackground : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: yes || unanswered ? const BorderSide(color: AppColors.statusProblem, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: yes ? Colors.white : AppColors.primarySoft,
                  child: Icon(
                    icon,
                    size: 30,
                    color: yes ? AppColors.statusProblem : AppColors.primary,
                    semanticLabel: label,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ChoiceButtons<bool>(
              options: [(true, l10n.answerYes), (false, l10n.answerNo)],
              selected: answer,
              danger: const {true},
              onSelected: onAnswer,
            ),
            if (unanswered)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.dangerUnanswered,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
