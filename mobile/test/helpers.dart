import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:mediqore/app.dart';
import 'package:mediqore/app_services.dart';
import 'package:mediqore/data/app_database.dart';
import 'package:mediqore/l10n/app_localizations.dart';
import 'package:mediqore/sync/sync_api.dart';
import 'package:mediqore/theme/app_theme.dart';

import 'support/fake_sync_server.dart';

/// Wraps [child] in the app's theme and localisation (Urdu by default), so a
/// widget can be tested on its own.
Widget wrapInApp(Widget child, {Locale locale = MediQoreApp.urdu}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [child])),
  );
}

/// App services backed by an in-memory database and [server]. Close
/// `services.db` at the end of the test.
AppServices testServices([FakeSyncServer? server]) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppServices(
    db: AppDatabase(NativeDatabase.memory()),
    api: SyncApi(client: (server ?? FakeSyncServer()).client, baseUrl: 'http://test/api/v1'),
  );
}
