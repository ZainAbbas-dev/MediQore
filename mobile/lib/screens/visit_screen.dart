// M3 FE-1, FE-3: the home visit form (P0-7 screen 4, scope Mockup 2). Vitals
// with their units, symptoms as checkboxes and dropdowns, saved on the phone
// with no internet needed. Values that are impossible cannot be saved; values
// outside the usual range are saved only after the LHW confirms them. The
// ranges come from assets/clinical/visit_ranges.json. In Urdu, each field's
// label is read aloud when it gets focus, unless voice guidance is muted.
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../clinical/visit_ranges.dart';
import '../data/app_database.dart';
import '../data/visit_repository.dart';
import '../l10n/app_localizations.dart';
import '../voice/voice_guide.dart';
import '../widgets/form_fields.dart';
import '../widgets/large_button.dart';
import '../widgets/offline_status_bar.dart';

/// A value outside its usual range, for the confirmation dialog.
class _Unusual {
  const _Unusual(this.label, this.value, this.unit, this.range);

  final String label;
  final String value;
  final String unit;
  final VitalRange range;
}

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
  final _form = GlobalKey<FormState>();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _weight = TextEditingController();
  final _temperature = TextEditingController();
  final _pulse = TextEditingController();
  final _sugar = TextEditingController();

  String? _fetalMovement;
  bool _swelling = false;
  bool _bleeding = false;
  bool _fever = false;
  bool _urine = false;
  String _anaemia = 'none';

  VisitRanges? _ranges;
  int _pending = 0;
  bool _saving = false;
  bool _hasErrors = false;

  AppServices get _services => widget.services;

  @override
  void initState() {
    super.initState();
    _ranges = widget.ranges ?? _services.visitRanges;
    if (_ranges == null) {
      VisitRanges.load().then((ranges) {
        if (mounted) setState(() => _ranges = ranges);
      });
    }
    _services.db.pendingCount().then((pending) {
      if (mounted) setState(() => _pending = pending);
    });
  }

  @override
  void dispose() {
    for (final c in [_systolic, _diastolic, _weight, _temperature, _pulse, _sugar]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _number(num n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';

  // Required, then possible (inside what the server accepts).
  FormFieldValidator<String> _vital(String field, AppLocalizations l10n, {bool required = true}) => (text) {
        final value = num.tryParse((text ?? '').trim());
        if ((text ?? '').trim().isEmpty) return required ? l10n.regErrorRequired : null;
        final range = _ranges![field];
        if (value == null || !range.isAllowed(value)) {
          return l10n.visitErrorNotPossible(_number(range.allowed.$1), _number(range.allowed.$2));
        }
        return null;
      };

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());
  double? _double(TextEditingController c) => double.tryParse(c.text.trim());

  Future<void> _save(AppLocalizations l10n) async {
    final valid = _form.currentState!.validate();
    setState(() => _hasErrors = !valid);
    if (!valid) return;

    final ranges = _ranges!;
    final unusual = <_Unusual>[
      for (final (field, label, controller, unit) in [
        ('systolicBpMmhg', l10n.fieldSystolicBp, _systolic, l10n.unitMmHg),
        ('diastolicBpMmhg', l10n.fieldDiastolicBp, _diastolic, l10n.unitMmHg),
        ('weightKg', l10n.fieldWeight, _weight, l10n.unitKg),
        ('temperatureC', l10n.fieldTemperature, _temperature, l10n.unitCelsius),
        ('pulseBpm', l10n.fieldPulse, _pulse, l10n.unitPerMinute),
        ('bloodSugarMmolL', l10n.fieldBloodSugar, _sugar, l10n.unitMmolL),
      ])
        if (num.tryParse(controller.text.trim()) case final value? when !ranges[field].isPlausible(value))
          _Unusual(label, controller.text.trim(), unit, ranges[field]),
    ];
    if (unusual.isNotEmpty && !await _confirmUnusual(unusual, l10n)) return;
    if (!mounted) return;

    setState(() => _saving = true);
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
          bloodSugarMmolL: _double(_sugar),
          fetalMovement: _fetalMovement,
          swelling: _swelling,
          bleeding: _bleeding,
          fever: _fever,
          anaemiaSigns: _anaemia,
          urineSymptoms: _urine,
        ),
        by: _services.session.user!,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.of(context).pop(visit);
  }

  // M3 FE-1: a value outside the usual range may be a typing error. It is
  // saved only if the LHW confirms it.
  Future<bool> _confirmUnusual(List<_Unusual> unusual, AppLocalizations l10n) async {
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
                        '${_number(item.range.plausible.$1)}–${_number(item.range.plausible.$2)} ${item.unit}',
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = _services.settings;
    final ranges = _ranges;

    Widget section(String title) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text(title, style: theme.textTheme.titleLarge),
        );
    const gap = SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.visitTitle),
        actions: [
          // M3 FE-3: mute toggle; voice guidance exists only in Urdu (M1 FE-4).
          ListenableBuilder(
            listenable: settings,
            builder: (context, _) => !settings.voiceGuidanceAvailable
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Icon(settings.voiceMuted ? Icons.volume_off : Icons.volume_up),
                    tooltip: settings.voiceMuted ? l10n.voiceUnmute : l10n.voiceMute,
                    onPressed: () => settings.setVoiceMuted(!settings.voiceMuted),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          ListenableBuilder(
            listenable: _services.autoSync,
            builder: (context, _) => OfflineStatusBar(
              isOnline: _services.autoSync.online ?? _services.session.isOnlineSession,
              pendingCount: _pending,
            ),
          ),
          Expanded(
            child: ranges == null
                ? const Center(child: CircularProgressIndicator())
                : VoiceScope(
                    guidance: _services.voice,
                    child: Form(
                      key: _form,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(widget.title, style: theme.textTheme.titleMedium),
                            section(l10n.visitVitalsSection),
                            VitalField(
                              label: l10n.fieldSystolicBp,
                              unit: l10n.unitMmHg,
                              controller: _systolic,
                              validator: _vital('systolicBpMmhg', l10n),
                            ),
                            gap,
                            VitalField(
                              label: l10n.fieldDiastolicBp,
                              unit: l10n.unitMmHg,
                              controller: _diastolic,
                              validator: (text) {
                                final problem = _vital('diastolicBpMmhg', l10n)(text);
                                if (problem != null) return problem;
                                final systolic = _int(_systolic);
                                return systolic != null && int.parse(text!.trim()) >= systolic
                                    ? l10n.visitErrorDiastolic
                                    : null;
                              },
                            ),
                            gap,
                            VitalField(
                              label: l10n.fieldWeight,
                              unit: l10n.unitKg,
                              decimals: ranges['weightKg'].decimals,
                              controller: _weight,
                              validator: _vital('weightKg', l10n),
                            ),
                            gap,
                            VitalField(
                              label: l10n.fieldTemperature,
                              unit: l10n.unitCelsius,
                              decimals: ranges['temperatureC'].decimals,
                              controller: _temperature,
                              validator: _vital('temperatureC', l10n),
                            ),
                            gap,
                            VitalField(
                              label: l10n.fieldPulse,
                              unit: l10n.unitPerMinute,
                              controller: _pulse,
                              validator: _vital('pulseBpm', l10n),
                            ),
                            gap,
                            VitalField(
                              label: l10n.fieldBloodSugar,
                              unit: l10n.unitMmolL,
                              decimals: ranges['bloodSugarMmolL'].decimals,
                              controller: _sugar,
                              validator: _vital('bloodSugarMmolL', l10n, required: false),
                            ),
                            section(l10n.visitSymptomsSection),
                            DropdownField<String>(
                              label: l10n.fieldFetalMovement,
                              value: _fetalMovement,
                              options: [
                                DropdownOption('normal', l10n.fetalMovementNormal),
                                DropdownOption('reduced', l10n.fetalMovementReduced),
                                DropdownOption('absent', l10n.fetalMovementAbsent),
                              ],
                              onChanged: (value) => setState(() => _fetalMovement = value),
                            ),
                            gap,
                            CheckboxField(
                              label: l10n.fieldSwelling,
                              value: _swelling,
                              onChanged: (v) => setState(() => _swelling = v),
                            ),
                            CheckboxField(
                              label: l10n.fieldBleeding,
                              value: _bleeding,
                              onChanged: (v) => setState(() => _bleeding = v),
                            ),
                            CheckboxField(label: l10n.fieldFever, value: _fever, onChanged: (v) => setState(() => _fever = v)),
                            CheckboxField(
                              label: l10n.fieldUrineSymptoms,
                              value: _urine,
                              onChanged: (v) => setState(() => _urine = v),
                            ),
                            gap,
                            DropdownField<String>(
                              label: l10n.fieldAnaemia,
                              value: _anaemia,
                              options: [
                                DropdownOption('none', l10n.anaemiaNone),
                                DropdownOption('present', l10n.anaemiaPresent),
                                DropdownOption('severe', l10n.anaemiaSevere),
                              ],
                              onChanged: (value) => setState(() => _anaemia = value ?? 'none'),
                            ),
                            const SizedBox(height: 24),
                            if (_hasErrors) ...[
                              Text(l10n.regErrorFix, style: TextStyle(color: theme.colorScheme.error)),
                              gap,
                            ],
                            LargeButton(
                              label: l10n.visitSaveButton,
                              icon: Icons.save,
                              onPressed: _saving ? null : () => _save(l10n),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
