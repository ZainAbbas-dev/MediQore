import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/clinical/visit_ranges.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/location/location_service.dart';
import 'package:mediqore/settings/app_settings.dart';
import 'package:mediqore/sync/sync_api.dart';
import 'package:mediqore/theme/app_theme.dart';

import 'support/fake_location_service.dart';
import 'support/fake_voice.dart';
import 'support/memory_database_opener.dart';
import 'support/fake_sync_server.dart';

/// Wraps [child] in the app's theme and localisation (Urdu by default), so a
/// widget can be tested on its own.
Widget wrapInApp(Widget child, {Locale locale = AppSettings.urdu}) {
  return MaterialApp(
    theme: AppTheme.light(urdu: locale == AppSettings.urdu),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [child])),
  );
}

/// App services backed by an in-memory database and [server]. Settings start
/// in Urdu and are kept in memory unless [settings] is given. Password keys use
/// few PBKDF2 iterations so tests run fast, the GPS is a [FakeLocationService]
/// unless [location] is given, and the voice is a [FakeVoice] unless [voice] is
/// given. Records sync only when a test asks (no automatic sync, no timers).
/// The visit form's ranges are the app's config file.
/// Call `services.dispose()` at the end.
///
/// The database opens at sign-in, as on the phone. [dbOf] reaches it while the
/// app is locked.
AppServices testServices([
  FakeSyncServer? server,
  AppSettings? settings,
  Duration? autoLockAfter,
  LocationService? location,
  FakeVoice? voice,
]) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppServices(
    opener: MemoryDatabaseOpener(),
    api: SyncApi(client: (server ?? FakeSyncServer()).client, baseUrl: 'http://test/api/v1'),
    settings: settings,
    autoLockAfter: autoLockAfter,
    passwordIterations: 1000,
    location: location ?? FakeLocationService(),
    voice: voice ?? FakeVoice(),
    autoSync: false,
    visitRanges: visitRanges,
  );
}

/// The app's visit range config (assets/clinical/visit_ranges.json), read
/// without the asset bundle.
final VisitRanges visitRanges = VisitRanges.fromJson(
  jsonDecode(File(VisitRanges.asset).readAsStringSync()) as Map<String, dynamic>,
);

/// Signs [services] in through an already approved phone, for tests that need
/// a signed-in session but are not about signing in.
Future<void> signInApproved(AppServices services, FakeSyncServer server) async {
  server.approve(services.settings.deviceId);
  await services.session.signIn(server.username, server.password);
}

/// The test database, also while the app is locked (on the phone it would be
/// closed and encrypted).
AppDatabase dbOf(AppServices services) => (services.opener as MemoryDatabaseOpener).db;
