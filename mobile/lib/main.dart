// M3 FE-1: app shell, Urdu and right to left by default (P0-2), with the Phase 0 sync check (P0-6).
// M1 FE-4: the saved interface language (Urdu or English) is read before the first frame.
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_services.dart';
import 'clinical/visit_ranges.dart';
import 'settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  // M3 FE-1: the visit form's range checks, from the versioned config file.
  final visitRanges = await VisitRanges.load();
  runApp(MediQoreApp(services: AppServices.onDevice(settings: settings, visitRanges: visitRanges)));
}
