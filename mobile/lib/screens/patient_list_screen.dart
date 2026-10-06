// M2 FE-3: the women registered in the LHW's area, searchable and grouped by
// village. Everything comes from the phone, so it works offline.
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/patient_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/app_cards.dart';
import 'patient_file_screen.dart';
import 'register_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _search = TextEditingController();
  List<PatientSummary>? _patients;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final search = _search.text;
    final patients = await widget.services.patients.list(search: search);
    final total = search.trim().isEmpty ? patients.length : (await widget.services.patients.list()).length;
    if (!mounted || search != _search.text) return; // a newer search is on its way
    setState(() {
      _patients = patients;
      _total = total;
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final patients = _patients;

    final rows = <Widget>[];
    String? village;
    for (final (index, p) in (patients ?? const <PatientSummary>[]).indexed) {
      final pVillage = p.village?.trim().isEmpty ?? true ? null : p.village!.trim();
      if (index == 0 || pVillage != village) {
        village = pVillage;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Row(
              children: [
                Icon(Icons.place, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    village ?? l10n.patientsNoVillage,
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PatientRow(
            patient: p,
            onTap: () => _open(PatientFileScreen(services: widget.services, womanId: p.woman.id)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.patientsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: Text(l10n.patientsNewButton),
        tooltip: l10n.homeRegisterButton,
        onPressed: () => _open(RegisterScreen(services: widget.services)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.primary,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                controller: _search,
                onChanged: (_) => _load(),
                decoration: InputDecoration(
                  hintText: l10n.patientsSearch,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(28)), borderSide: BorderSide.none),
                  enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(28)), borderSide: BorderSide.none),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(28)), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          if (patients != null && _total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(l10n.patientsCount(patients.length), style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
            ),
          Expanded(
            child: patients == null
                ? const Center(child: CircularProgressIndicator())
                : patients.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: NoticeCard(text: _total == 0 ? l10n.patientsEmpty : l10n.patientsNoMatch),
                  )
                // Room at the end so the last woman is not hidden under the button.
                : ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 96), children: rows),
          ),
        ],
      ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.onTap});

  final PatientSummary patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final woman = patient.woman;
    final pregnancy = patient.pregnancy;
    final details = [
      if (woman.age != null) l10n.patientAge(woman.age!),
      if (pregnancy != null) l10n.patientMonthAtRegistration(pregnancy.pregnancyMonthAtRegistration),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              InitialAvatar(woman.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(woman.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      woman.patientCode,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
                    ),
                    if (details.isNotEmpty) Text(details.join(' · '), style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    SyncStatusChip(patient.syncStatus),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}
