// M2 FE-1, FE-2, FE-3: registration of a pregnant woman (P0-7 screen 3). The
// woman, her pregnancy month, her home with its GPS position and her obstetric
// history are on one scrolling page, captured at the time of registration, and
// saved on the phone in one step. No internet is needed.
// M3 FE-3: in Urdu, each field's label is read aloud when it gets focus, unless
// voice guidance is muted (the speaker button in the app bar).
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/app_database.dart';
import '../data/patient_repository.dart';
import '../l10n/app_localizations.dart';
import '../location/location_service.dart';
import '../voice/voice_guide.dart';
import '../widgets/app_cards.dart';
import '../widgets/form_fields.dart';
import '../widgets/gps_capture.dart';
import '../widgets/large_button.dart';
import '../widgets/offline_status_bar.dart';
import 'registration_saved_screen.dart';

/// Pregnancy months offered on the form (P0-7 screen spec: dropdown 1–9).
const List<int> pregnancyMonths = [1, 2, 3, 4, 5, 6, 7, 8, 9];

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
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _husbandName = TextEditingController();
  final _contact = TextEditingController();
  final _village = TextEditingController();
  final _address = TextEditingController();
  final _previous = TextEditingController(text: '0');
  final _cSections = TextEditingController(text: '0');
  final _stillbirths = TextEditingController(text: '0');
  final _conditions = TextEditingController();

  int? _month;
  bool _sameHome = false;
  String? _homeOf;
  List<PatientSummary> _registered = const [];
  LocationFix? _fix;
  bool _saving = false;
  bool _hasErrors = false;

  @override
  void initState() {
    super.initState();
    widget.services.patients.list().then((women) {
      if (mounted) setState(() => _registered = women);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _age, _husbandName, _contact, _village, _address, _previous, _cSections, _stillbirths, _conditions]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _optional(String text) => text.trim().isEmpty ? null : text.trim();

  Future<void> _save(AppLocalizations l10n) async {
    final valid = _form.currentState!.validate();
    setState(() => _hasErrors = !valid);
    if (!valid) return;

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
          previousPregnancies: int.parse(_previous.text),
          previousCSections: int.parse(_cSections.text),
          stillbirths: int.parse(_stillbirths.text),
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
    String? required(String? text) => (text ?? '').trim().isEmpty ? l10n.regErrorRequired : null;
    String? count(String? text) {
      final value = int.tryParse(text ?? '');
      return value == null || value > 30 ? l10n.regErrorCount : null;
    }

    String? notMoreThanPregnancies(String? text) {
      final problem = count(text);
      if (problem != null) return problem;
      final previous = int.tryParse(_previous.text);
      return previous != null && int.parse(text!) > previous ? l10n.regErrorMoreThanPregnancies : null;
    }

    const gap = SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.regTitle),
        actions: [VoiceMuteButton(settings: widget.services.settings)],
      ),
      body: Column(
        children: [
          LiveStatusBar(services: widget.services),
          Expanded(
            child: VoiceScope(
              guidance: widget.services.voice,
              child: Form(
                key: _form,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionCard(
                        title: l10n.regWomanSection,
                        icon: Icons.person,
                        children: [
                          AppTextField(label: l10n.regName, controller: _name, validator: required),
                          NumberField(
                            label: l10n.regAge,
                            controller: _age,
                            validator: (text) {
                              final age = int.tryParse(text ?? '');
                              return age == null || age < 10 || age > 60 ? l10n.regErrorAge : null;
                            },
                          ),
                          AppTextField(label: l10n.regHusbandName, controller: _husbandName),
                          AppTextField(
                            label: l10n.regContactNumber,
                            controller: _contact,
                            keyboardType: TextInputType.phone,
                            ltr: true,
                            validator: (text) {
                              final value = _withoutSpaces(text ?? '');
                              return value.isEmpty || _mobileNumber.hasMatch(value) ? null : l10n.regErrorContact;
                            },
                          ),
                        ],
                      ),
                      gap,
                      SectionCard(
                        title: l10n.regPregnancySection,
                        icon: Icons.pregnant_woman,
                        children: [
                          DropdownField<int>(
                            label: l10n.regPregnancyMonth,
                            value: _month,
                            options: [for (final m in pregnancyMonths) DropdownOption(m, l10n.regMonthOption(m))],
                            onChanged: (m) => setState(() => _month = m),
                            validator: (m) => m == null ? l10n.regErrorChooseMonth : null,
                          ),
                        ],
                      ),
                      gap,
                      SectionCard(
                        title: l10n.regHomeSection,
                        icon: Icons.home,
                        children: [
                          if (_registered.isNotEmpty)
                            CheckboxField(label: l10n.regSameHome, value: _sameHome, onChanged: (same) => setState(() => _sameHome = same)),
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
                            AppTextField(label: l10n.regVillage, controller: _village, validator: required),
                            AppTextField(label: l10n.regAddress, controller: _address),
                            GpsCapture(location: widget.services.location, onCaptured: (fix) => _fix = fix),
                          ],
                        ],
                      ),
                      gap,
                      SectionCard(
                        title: l10n.regHistorySection,
                        icon: Icons.history,
                        children: [
                          NumberField(label: l10n.regPreviousPregnancies, controller: _previous, validator: count),
                          NumberField(label: l10n.regPreviousCSections, controller: _cSections, validator: notMoreThanPregnancies),
                          NumberField(label: l10n.regStillbirths, controller: _stillbirths, validator: notMoreThanPregnancies),
                          AppTextField(label: l10n.regKnownConditions, controller: _conditions),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_hasErrors) ...[NoticeCard(text: l10n.regErrorFix, warning: true), gap],
                      LargeButton(label: l10n.regSaveButton, icon: Icons.save, onPressed: _saving ? null : () => _save(l10n)),
                      const SizedBox(height: 16),
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
