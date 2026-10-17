// M2 FE-1, FE-2, FE-3: registration of a pregnant woman, a four-step wizard
// (final design screens 8–11): the woman, the pregnancy month, the home with
// its GPS position, and the earlier pregnancies. Each step is checked before
// the next; the last step saves everything on the phone in one transaction.
// No internet is needed.
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/app_database.dart';
import '../data/patient_repository.dart';
import '../l10n/app_localizations.dart';
import '../location/location_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_cards.dart';
import '../widgets/form_fields.dart';
import '../widgets/gps_capture.dart';
import '../widgets/offline_status_bar.dart';
import '../widgets/step_scaffold.dart';
import 'registration_saved_screen.dart';

/// A mobile number as LHWs write it: 03001234567, or +923001234567. Spaces and
/// dashes are allowed while typing and removed before saving.
final RegExp _mobileNumber = RegExp(r'^(03\d{9}|\+923\d{9})$');

String _withoutSpaces(String text) => text.replaceAll(RegExp(r'[\s-]'), '');

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const int _steps = 4;
  final _forms = [for (var i = 0; i < _steps; i++) GlobalKey<FormState>()];
  int _step = 0;
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _husbandName = TextEditingController();
  final _contact = TextEditingController();
  final _village = TextEditingController();
  final _address = TextEditingController();
  final _conditions = TextEditingController();
  int _previous = 0;
  int _cSections = 0;
  int _stillbirths = 0;

  int? _month;
  bool _sameHome = false;
  String? _homeOf;
  List<PatientSummary> _registered = const [];
  LocationFix? _fix;
  bool _saving = false;
  bool _monthMissing = false;

  @override
  void initState() {
    super.initState();
    widget.services.patients.list().then((women) {
      if (mounted) setState(() => _registered = women);
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _age,
      _husbandName,
      _contact,
      _village,
      _address,
      _conditions,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _optional(String text) => text.trim().isEmpty ? null : text.trim();

  // Checks the current step; moves on, or saves after the last one.
  Future<void> _next() async {
    final valid = _forms[_step].currentState!.validate();
    final monthMissing = _step == 1 && _month == null;
    setState(() => _monthMissing = monthMissing);
    if (!valid || monthMissing) return;
    if (_step < _steps - 1) {
      setState(() => _step++);
    } else {
      await _save();
    }
  }

  void _back() => setState(() => _step--);

  Future<void> _save() async {
    setState(() => _saving = true);
    final services = widget.services;
    final householdId = _sameHome ? _registered.firstWhere((p) => p.woman.id == _homeOf).woman.householdId : null;
    final contact = _optional(_contact.text);
    final LocalWoman woman;
    try {
      woman = await services.patients.register(
        RegistrationInput(
          name: _name.text.trim(),
          age: int.parse(_age.text),
          husbandName: _optional(_husbandName.text),
          contactNumber: contact == null ? null : _withoutSpaces(contact),
          pregnancyMonth: _month!,
          householdId: householdId,
          village: householdId == null ? _optional(_village.text) : null,
          address: householdId == null ? _optional(_address.text) : null,
          latitude: householdId == null ? _fix?.latitude : null,
          longitude: householdId == null ? _fix?.longitude : null,
          previousPregnancies: _previous,
          previousCSections: _cSections,
          stillbirths: _stillbirths,
          knownConditions: _optional(_conditions.text),
        ),
        by: services.session.user!,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RegistrationSavedScreen(services: services, woman: woman),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String? required(String? text) => (text ?? '').trim().isEmpty ? l10n.regErrorRequired : null;
    const gap = SizedBox(height: 16);
    final question = theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);

    final (name, content) = switch (_step) {
      0 => (
        l10n.regWomanSection,
        <Widget>[
          Text(l10n.regWomanQuestion, style: question),
          AppTextField(label: l10n.regName, controller: _name, validator: required, icon: Icons.person_outline),
          NumberField(
            label: l10n.regAge,
            controller: _age,
            icon: Icons.cake_outlined,
            validator: (text) {
              final age = int.tryParse(text ?? '');
              return age == null || age < 10 || age > 60 ? l10n.regErrorAge : null;
            },
          ),
          AppTextField(label: l10n.regHusbandName, controller: _husbandName, icon: Icons.man_outlined),
          AppTextField(
            label: l10n.regContactNumber,
            controller: _contact,
            keyboardType: TextInputType.phone,
            ltr: true,
            icon: Icons.phone_outlined,
            validator: (text) {
              final value = _withoutSpaces(text ?? '');
              return value.isEmpty || _mobileNumber.hasMatch(value) ? null : l10n.regErrorContact;
            },
          ),
        ],
      ),
      1 => (
        l10n.regPregnancySection,
        <Widget>[
          Text(l10n.regMonthQuestion, style: question),
          Text(l10n.regMonthHint, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
          _MonthGrid(
            selected: _month,
            onSelected: (month) => setState(() {
              _month = month;
              _monthMissing = false;
            }),
          ),
          if (_month != null) NoticeCard(text: l10n.regMonthChosen(_month!), tone: NoticeTone.success),
          if (_monthMissing) NoticeCard(text: l10n.regErrorChooseMonth, tone: NoticeTone.problem),
        ],
      ),
      2 => (
        l10n.regHomeSection,
        <Widget>[
          Text(l10n.regHomeQuestion, style: question),
          if (_registered.isNotEmpty)
            Card(
              child: CheckboxField(
                label: l10n.regSameHome,
                value: _sameHome,
                onChanged: (same) => setState(() => _sameHome = same),
              ),
            ),
          if (_sameHome)
            DropdownField<String>(
              label: l10n.regChooseWoman,
              value: _homeOf,
              options: [
                for (final p in _registered)
                  DropdownOption(p.woman.id, l10n.regWomanOption(p.woman.name, p.woman.patientCode)),
              ],
              onChanged: (id) => setState(() => _homeOf = id),
              validator: (id) => id == null ? l10n.regErrorChooseWoman : null,
            )
          else ...[
            AppTextField(
              label: l10n.regVillage,
              controller: _village,
              validator: required,
              icon: Icons.holiday_village_outlined,
            ),
            AppTextField(label: l10n.regAddress, controller: _address, icon: Icons.home_outlined),
            SectionCard(
              title: l10n.gpsLabel,
              icon: Icons.location_on_outlined,
              children: [
                Text(l10n.gpsHint, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
                GpsCapture(location: widget.services.location, onCaptured: (fix) => _fix = fix, initial: _fix, showLabel: false),
              ],
            ),
          ],
        ],
      ),
      _ => (
        l10n.regHistorySection,
        <Widget>[
          Text(l10n.regHistorySection, style: question),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CounterField(
                    label: l10n.regPreviousPregnancies,
                    value: _previous,
                    onChanged: (n) => setState(() => _previous = n),
                  ),
                  const Divider(height: 24),
                  CounterField(
                    label: l10n.regPreviousCSections,
                    value: _cSections,
                    onChanged: (n) => setState(() => _cSections = n),
                    errorText: _cSections > _previous ? l10n.regErrorMoreThanPregnancies : null,
                  ),
                  const Divider(height: 24),
                  CounterField(
                    label: l10n.regStillbirths,
                    value: _stillbirths,
                    onChanged: (n) => setState(() => _stillbirths = n),
                    errorText: _stillbirths > _previous ? l10n.regErrorMoreThanPregnancies : null,
                  ),
                ],
              ),
            ),
          ),
          // Counts above the earlier pregnancies keep the form from saving.
          FormField<void>(
            validator: (_) => _cSections > _previous || _stillbirths > _previous ? l10n.regErrorMoreThanPregnancies : null,
            builder: (_) => const SizedBox.shrink(),
          ),
          AppTextField(
            label: l10n.regKnownConditions,
            controller: _conditions,
            icon: Icons.medical_information_outlined,
          ),
        ],
      ),
    };

    return StepScaffold(
      title: l10n.regTitle,
      step: _step + 1,
      total: _steps,
      stepName: name,
      statusBar: LiveStatusBar(services: widget.services, compact: true),
      busy: _saving,
      onBack: _step == 0 ? null : _back,
      nextLabel: _step == _steps - 1 ? l10n.regSaveButton : l10n.stepNext,
      onNext: _next,
      child: Form(
        key: _forms[_step],
        // A Column in a scroll view, not a ListView, so every field is built and validated.
        child: SingleChildScrollView(
          key: ValueKey(_step),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final (i, w) in content.indexed) ...[if (i > 0) gap, w]],
          ),
        ),
      ),
    );
  }
}

/// The months 1–9 as large buttons in a 3 × 3 grid, numbers left to right.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget month(int m) {
      final chosen = m == selected;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Semantics(
            selected: chosen,
            child: OutlinedButton(
              onPressed: () => onSelected(m),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                backgroundColor: chosen ? AppColors.primary : AppColors.surface,
                foregroundColor: chosen ? Colors.white : AppColors.text,
                side: BorderSide(color: chosen ? AppColors.primary : AppColors.fieldBorder),
              ),
              child: Text('$m', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          for (final row in [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9],
          ])
            Row(children: [for (final m in row) month(m)]),
        ],
      ),
    );
  }
}
