// M3 FE-1: app shell, Urdu and right to left by default (P0-2), with the Phase 0 sync check (P0-6).
// M1 FE-4: the saved interface language (Urdu or English) is read before the first frame.
// M3 FE-2: background sync is set up once the app runs.
import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'app_services.dart';
import 'clinical/clinical_rules.dart';
import 'settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  // P0-11: the Clinical Rules Table (visit ranges, obstetric flags), from the versioned config file.
  final clinicalRules = await ClinicalRules.load();
  final services = AppServices.onDevice(settings: settings, clinicalRules: clinicalRules);
  runApp(MediQoreApp(services: services));
  unawaited(
    services.backgroundScheduler.start().catchError((Object error) {
      debugPrint('Background sync not set up: $error');
    }),
  );
}
