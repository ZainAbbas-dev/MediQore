// M2 FE-3: the women registered in the LHW's area (final design screen 13),
// searchable, grouped by village, or sorted by the estimated distance from
// where the LHW stands (GPS, no maps or internet needed). Everything comes from
// the phone, so it works offline.
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/patient_repository.dart';
import '../l10n/app_localizations.dart';
import '../location/location_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_cards.dart';
import '../widgets/curved_header.dart';
import '../widgets/gps_capture.dart' show locationProblemText;
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
  int _villages = 0;

  // Sorted by distance from this position (M2 FE-3), or by village when null.
  ({double latitude, double longitude})? _near;
  bool _locating = false;
  LocationProblem? _locationProblem;

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
    final near = _near;
    final patients = await widget.services.patients.list(search: search, near: near);
    final all = search.trim().isEmpty ? patients : await widget.services.patients.list();
    if (!mounted || search != _search.text || near != _near) return; // a newer request is on its way
    setState(() {
      _patients = patients;
      _total = all.length;
      _villages = {for (final p in all) if ((p.village ?? '').trim().isNotEmpty) p.village!.trim().toLowerCase()}.length;
    });
  }

  Future<void> _sortNearest(bool nearest) async {
    if (!nearest) {
      setState(() {
        _near = null;
        _locationProblem = null;
      });
      await _load();
      return;
    }
    setState(() {
      _locating = true;
      _locationProblem = null;
    });
    final result = await widget.services.location.current();
    if (!mounted) return;
    final fix = result.fix;
    setState(() {
      _locating = false;
      _locationProblem = result.problem;
      if (fix != null) _near = (latitude: fix.latitude, longitude: fix.longitude);
    });
    await _load();
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
    final byDistance = _near != null;
    for (final (index, p) in (patients ?? const <PatientSummary>[]).indexed) {
      final pVillage = p.village?.trim().isEmpty ?? true ? null : p.village!.trim();
      if (!byDistance && (index == 0 || pVillage != village)) {
        village = pVillage;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, size: 20, color: theme.colorScheme.primary),
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
          padding: EdgeInsets.only(bottom: 8, top: byDistance && index == 0 ? 12 : 0),
          child: _PatientRow(
            patient: p,
            byDistance: byDistance,
            onTap: () => _open(PatientFileScreen(services: widget.services, womanId: p.woman.id)),
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(l10n.patientsNewButton),
        onPressed: () => _open(RegisterScreen(services: widget.services)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CurvedHeader(
            title: l10n.patientsTitle,
            subtitle: patients == null ? null : '${l10n.patientsCount(_total)} · ${l10n.patientsVillages(_villages)}',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l10n.patientsSortVillage), icon: const Icon(Icons.holiday_village_outlined)),
                ButtonSegment(value: true, label: Text(l10n.patientsSortNearest), icon: const Icon(Icons.near_me_outlined)),
              ],
              selected: {byDistance || _locating},
              style: SegmentedButton.styleFrom(
                minimumSize: const Size(0, 52),
                textStyle: theme.textTheme.titleSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                backgroundColor: AppColors.surface,
                selectedBackgroundColor: AppColors.primaryLight,
                selectedForegroundColor: AppColors.primaryDark,
              ),
              onSelectionChanged: _locating ? null : (choice) => _sortNearest(choice.single),
            ),
          ),
          if (_locating)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l10n.gpsCapturing)),
                ],
              ),
            ),
          if (_locationProblem != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: NoticeCard(text: locationProblemText(l10n, _locationProblem!), tone: NoticeTone.problem),
            ),
          Expanded(
            child: patients == null
                ? const Center(child: CircularProgressIndicator())
                : patients.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      EmptyNote(
                        text: _total == 0 ? l10n.patientsEmpty : l10n.patientsNoMatch,
                        icon: _total == 0 ? Icons.groups_outlined : Icons.search_off,
                      ),
                    ],
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
  const _PatientRow({required this.patient, required this.onTap, this.byDistance = false});

  final PatientSummary patient;
  final VoidCallback onTap;

  /// Sorted by distance: the row shows the village and the distance.
  final bool byDistance;

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
                    if (byDistance)
                      Text(
                        [
                          ?patient.village,
                          patient.distanceKm == null
                              ? l10n.patientsNoGps
                              : l10n.patientsDistance(patient.distanceKm!.toStringAsFixed(1)),
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.primaryDark),
                      ),
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
