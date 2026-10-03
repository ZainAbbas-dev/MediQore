// M3 FE-2: Phase 0 end-to-end check (P0-6): one test record created offline,
// synced, stored in PostgreSQL and visible on the portal.
import 'dart:math';

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/app_database.dart';
import '../l10n/app_localizations.dart';
import '../sync/sync_api.dart';
import '../widgets/form_fields.dart';
import '../widgets/large_button.dart';
import '../widgets/offline_status_bar.dart';

/// Signs in as an LHW, saves synthetic test households on the phone (works
/// offline), and syncs them on demand. Replaced by the real screens in Phase 1.
class SyncTestScreen extends StatefulWidget {
  const SyncTestScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<SyncTestScreen> createState() => _SyncTestScreenState();
}

class _SyncTestScreenState extends State<SyncTestScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _random = Random();

  String? _token;
  String? _signedInAs;
  bool _busy = false;
  bool _lastSyncOk = false;
  String? _message;
  List<LocalHousehold> _households = const [];
  int _pending = 0;
  int _lastServerSeq = 0;

  AppServices get _services => widget.services;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final households = await _services.households.all();
    final pending = await _services.db.pendingCount();
    final lastSeq = await _services.sync.lastServerSeq();
    if (!mounted) return;
    setState(() {
      _households = households;
      _pending = pending;
      _lastServerSeq = lastSeq;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  String _reason(Object error) => error is ApiException ? error.code : error.runtimeType.toString();

  Future<void> _signIn(AppLocalizations l10n) => _run(() async {
        try {
          final token = await _services.api.login(_username.text.trim(), _password.text);
          setState(() {
            _token = token;
            _signedInAs = _username.text.trim();
            _message = null;
          });
        } catch (error) {
          setState(() => _message = l10n.signInFailed(_reason(error)));
        }
      });

  // Synthetic household near Islamabad (LI-10: no real patient data). Real GPS
  // capture comes with M2 FE-3.
  Future<void> _createTestHousehold(AppLocalizations l10n) => _run(() async {
        await _services.households.create(
          householdNumber: 'TEST-${_households.length + 1}',
          village: l10n.testHouseholdVillage,
          latitude: 33.6844 + (_random.nextDouble() - 0.5) / 50,
          longitude: 73.0479 + (_random.nextDouble() - 0.5) / 50,
        );
      });

  Future<void> _syncNow(AppLocalizations l10n) => _run(() async {
        try {
          final report = await _services.sync.syncNow(_token!);
          setState(() {
            _lastSyncOk = true;
            _message = l10n.syncResult(report.pushed, report.pulled, report.rejected);
          });
        } catch (error) {
          setState(() {
            _lastSyncOk = false;
            _message = l10n.syncFailed(_reason(error));
          });
        }
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signedIn = _token != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncTestTitle)),
      body: Column(
        children: [
          OfflineStatusBar(isOnline: _lastSyncOk, pendingCount: _pending),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!signedIn) ...[
                  AppTextField(label: l10n.fieldUsername, controller: _username),
                  const SizedBox(height: 12),
                  AppTextField(label: l10n.fieldPassword, controller: _password, obscureText: true),
                  const SizedBox(height: 12),
                  LargeButton(label: l10n.signInButton, icon: Icons.login, onPressed: _busy ? null : () => _signIn(l10n)),
                ] else
                  Text(l10n.signedInAs(_signedInAs!), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                LargeButton(
                  label: l10n.createTestHousehold,
                  icon: Icons.add_home,
                  secondary: true,
                  onPressed: _busy ? null : () => _createTestHousehold(l10n),
                ),
                const SizedBox(height: 12),
                LargeButton(
                  label: signedIn ? l10n.syncNowButton : l10n.signInFirst,
                  icon: Icons.sync,
                  onPressed: _busy || !signedIn ? null : () => _syncNow(l10n),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!, style: Theme.of(context).textTheme.bodyLarge),
                ],
                const SizedBox(height: 16),
                Text(l10n.localHouseholdCount(_households.length), style: Theme.of(context).textTheme.titleMedium),
                Text(l10n.lastServerSeq(_lastServerSeq)),
                for (final h in _households)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(h.serverSeq == null ? Icons.cloud_upload : Icons.cloud_done),
                    title: Text('${h.householdNumber ?? ''} · ${h.village ?? ''}'),
                    subtitle: Text(h.serverSeq == null ? l10n.householdWaiting : l10n.householdSynced(h.serverSeq!)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
