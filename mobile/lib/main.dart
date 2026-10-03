// M3 FE-1: Urdu, right-to-left app shell (P0-2) with the Phase 0 sync check (P0-6).
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_services.dart';

void main() {
  runApp(MediQoreApp(services: AppServices.onDevice()));
}
