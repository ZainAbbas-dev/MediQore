import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/settings/app_settings.dart';
import 'package:mediqore/sync/sync_api.dart';
import 'package:mediqore/theme/app_theme.dart';

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
/// few PBKDF2 iterations so tests run fast. Close `services.db` at the end.
AppServices testServices([FakeSyncServer? server, AppSettings? settings, Duration? autoLockAfter]) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppServices(
    db: AppDatabase(NativeDatabase.memory()),
    api: SyncApi(client: (server ?? FakeSyncServer()).client, baseUrl: 'http://test/api/v1'),
    settings: settings,
    autoLockAfter: autoLockAfter,
    passwordIterations: 1000,
  );
}

/// Signs [services] in through an already approved phone, for tests that need
/// a signed-in session but are not about signing in.
Future<void> signInApproved(AppServices services, FakeSyncServer server) async {
  server.approve(services.settings.deviceId);
  await services.session.signIn(server.username, server.password);
}
