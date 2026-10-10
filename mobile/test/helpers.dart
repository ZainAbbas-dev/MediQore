import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/auth/secure_store.dart';
import 'package:mediqore/auth/session.dart';
import 'package:mediqore/clinical/visit_ranges.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/location/location_service.dart';
import 'package:mediqore/settings/app_settings.dart';
import 'package:mediqore/sync/sync_api.dart';
import 'package:mediqore/theme/app_theme.dart';

import 'support/fake_dialer.dart';
import 'support/fake_location_service.dart';
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
/// in Urdu and are kept in memory unless [settings] is given; the Keystore is
/// a [MemorySecureStore] unless [secure] is given. PINs use few PBKDF2
/// iterations so tests run fast, the GPS is a [FakeLocationService] unless
/// [location] is given, and the dialer a [FakeDialer] unless [dialer] is given.
/// [clock] replaces the phone's clock for the wrong-PIN waits. Records sync
/// only when a test asks (no automatic sync, no timers). The visit form's
/// ranges are the app's config file. Call `services.dispose()` at the end.
///
/// The database opens at unlock, as on the phone. [dbOf] reaches it while the
/// app is locked.
AppServices testServices([
  FakeSyncServer? server,
  AppSettings? settings,
  Duration? autoLockAfter,
  LocationService? location,
  FakeDialer? dialer,
  DateTime Function()? clock,
  SecureStore? secure,
]) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppServices(
    opener: MemoryDatabaseOpener(),
    api: SyncApi(client: (server ?? FakeSyncServer()).client, baseUrl: 'http://test/api/v1'),
    secureStore: secure ?? MemorySecureStore(),
    settings: settings,
    autoLockAfter: autoLockAfter,
    pinIterations: 1000,
    clock: clock,
    location: location ?? FakeLocationService(),
    dialer: dialer ?? FakeDialer(),
    autoSync: false,
    visitRanges: visitRanges,
  );
}

/// The visit form ranges from the bundled Clinical Rules Table, read
/// without the asset bundle.
final VisitRanges visitRanges = VisitRanges.fromJson(
  jsonDecode(File(VisitRanges.asset).readAsStringSync()) as Map<String, dynamic>,
);

/// The PIN tests create at activation.
const String testPin = '135790';

/// Activates the phone with a code from [server] and creates [pin], so the app
/// is open: for tests that need an open app but are not about activation.
Future<void> activateApp(AppServices services, FakeSyncServer server, {String pin = testPin}) async {
  final code = server.issueActivationCode();
  final result = await services.session.activate(server.username, server.password, code);
  if (result != SignInResult.activated) throw StateError('Activation failed: $result');
  await services.session.completeActivation(pin);
}

/// The test database, also while the app is locked (on the phone it would be
/// closed and encrypted).
AppDatabase dbOf(AppServices services) => (services.opener as MemoryDatabaseOpener).db;
