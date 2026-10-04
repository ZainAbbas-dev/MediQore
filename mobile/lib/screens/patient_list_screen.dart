// M2 FE-3: the women registered in the LHW's area, searchable and grouped by
// village. Everything comes from the phone, so it works offline.
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/patient_repository.dart';
import '../l10n/app_localizations.dart';
import '../widgets/sync_status_text.dart';
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
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(village ?? l10n.patientsNoVillage, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
        ));
      }
      rows.add(_PatientRow(patient: p, onTap: () => _open(PatientFileScreen(services: widget.services, womanId: p.woman.id))));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.patientsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: l10n.homeRegisterButton,
            onPressed: () => _open(RegisterScreen(services: widget.services)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => _load(),
              decoration: InputDecoration(hintText: l10n.patientsSearch, prefixIcon: const Icon(Icons.search)),
            ),
          ),
          if (patients != null && _total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(l10n.patientsCount(patients.length), style: theme.textTheme.bodySmall),
            ),
          Expanded(
            child: patients == null
                ? const Center(child: CircularProgressIndicator())
                : patients.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_total == 0 ? l10n.patientsEmpty : l10n.patientsNoMatch, style: theme.textTheme.bodyLarge),
                      )
                    : ListView(padding: const EdgeInsets.only(bottom: 24), children: rows),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(woman.name, style: theme.textTheme.titleMedium),
                    Text(woman.patientCode, textDirection: TextDirection.ltr, style: theme.textTheme.bodyMedium),
                    if (details.isNotEmpty) Text(details.join(' · '), style: theme.textTheme.bodySmall),
                    if (syncStatusText(l10n, patient.syncStatus) case final status?)
                      Text(
                        status,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: patient.syncStatus == SyncStatus.refused ? theme.colorScheme.error : null,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                switch (patient.syncStatus) {
                  SyncStatus.synced => Icons.cloud_done,
                  SyncStatus.waiting => Icons.cloud_upload,
                  SyncStatus.refused => Icons.error,
                  SyncStatus.held => Icons.hourglass_top,
                },
                color: patient.syncStatus == SyncStatus.refused ? theme.colorScheme.error : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
