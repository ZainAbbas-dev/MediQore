// M1 FE-2, FE-4: the first screen after sign-in (P0-7 screen 2). It shows who
// is signed in and the sync status, opens registration and the patient list
// (M2), and holds the language switch, lock and sign-out. M3 adds visits.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_services.dart';
import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../sync/sync_api.dart';
import '../widgets/language_switch.dart';
import '../widgets/large_button.dart';
import '../widgets/offline_status_bar.dart';
import 'dev_home_screen.dart';
import 'patient_list_screen.dart';
import 'register_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _pending = 0;
  bool _online = false;
  bool _busy = false;
  String? _message;
  bool _needsSignIn = false;

  AppServices get _services => widget.services;

  @override
  void initState() {
    super.initState();
    _online = _services.session.isOnlineSession;
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    // After a lock the database is closed; the login screen replaces this one.
    final data = _services.session.data;
    if (data == null) return;
    final pending = await data.db.pendingCount();
    if (mounted) setState(() => _pending = pending);
  }

  // Opens a screen; the pending count may have changed when it closes.
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    await _refreshPending();
  }

  Future<void> _sync(AppLocalizations l10n) async {
    setState(() {
      _busy = true;
      _message = null;
      _needsSignIn = false;
    });
    try {
      final report = await _services.session.sync();
      _online = true;
      _message = l10n.syncResult(report.pushed, report.pulled, report.rejected);
    } on NeedsOnlineSignIn {
      _needsSignIn = true;
      _message = l10n.homeSyncNeedsSignIn;
    } on ApiException catch (error) {
      if (error.code == 'ACCOUNT_INACTIVE') return; // the session is locked; the login screen explains
      _message = l10n.syncFailed(error.code);
    } on Object catch (error) {
      if (error is! SocketException && error is! http.ClientException && error is! TimeoutException) rethrow;
      _online = false;
      _message = l10n.homeSyncOffline;
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refreshPending();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = _services.session;
    final user = session.user;
    if (user == null) return const SizedBox.shrink(); // locked; the app shows the login screen

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Column(
        children: [
          OfflineStatusBar(isOnline: _online, pendingCount: _pending),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(user.fullName, style: Theme.of(context).textTheme.titleLarge),
                if (user.lhwCode != null) Text(l10n.homeLhwCode(user.lhwCode!)),
                if (user.areaName != null) Text(l10n.homeArea(user.areaName!)),
                if (session.lostUnsyncedRecords) ...[
                  const SizedBox(height: 8),
                  Text(l10n.homeLostUnsynced, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (!session.isOnlineSession && _message == null) ...[
                  const SizedBox(height: 8),
                  Text(l10n.homeOfflineSignIn),
                ],
                const SizedBox(height: 16),
                if (user.lhwCode != null) ...[
                  // M2: registration and the patient list work without the internet.
                  LargeButton(
                    label: l10n.homeRegisterButton,
                    icon: Icons.person_add,
                    onPressed: () => _open(RegisterScreen(services: _services)),
                  ),
                  const SizedBox(height: 12),
                  LargeButton(
                    label: l10n.homePatientsButton,
                    icon: Icons.people,
                    secondary: true,
                    onPressed: () => _open(PatientListScreen(services: _services)),
                  ),
                  const SizedBox(height: 12),
                ],
                LargeButton(label: l10n.syncNowButton, icon: Icons.sync, onPressed: _busy ? null : () => _sync(l10n)),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!, style: Theme.of(context).textTheme.bodyLarge),
                ],
                if (_needsSignIn) ...[
                  const SizedBox(height: 12),
                  LargeButton(
                    label: l10n.homeSignInAgainButton,
                    icon: Icons.login,
                    secondary: true,
                    onPressed: () => session.lock(null),
                  ),
                ],
                const SizedBox(height: 24),
                LanguageSwitch(settings: _services.settings),
                const SizedBox(height: 24),
                LargeButton(label: l10n.homeLockButton, icon: Icons.lock, secondary: true, onPressed: () => session.lock(null)),
                const SizedBox(height: 12),
                LargeButton(label: l10n.homeSignOutButton, icon: Icons.logout, secondary: true, onPressed: session.signOut),
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  LargeButton(
                    label: l10n.devHomeTitle,
                    icon: Icons.build,
                    secondary: true,
                    onPressed: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: (_) => DevHomeScreen(services: _services))),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
