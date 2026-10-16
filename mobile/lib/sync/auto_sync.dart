// M3 FE-2: records sync automatically when the phone is online (roadmap,
// Offline sync: "outbox with retry ... background sync when online"). While the
// app is unlocked and holds a working refresh token, the phone syncs:
// - shortly after a record is saved;
// - as soon as the network comes back (connectivity_plus);
// - every few minutes while records wait (the retry after a failed attempt),
//   and otherwise every [AutoSync.pullEvery] to fetch the area's changes;
// - when the app comes back to the foreground.
// When the app locks or goes to the background with records waiting, Android is
// asked to sync them in the background as soon as there is a network
// (background_sync.dart). The app and background sync never sync at the same
// time (SyncGate).
import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/widgets.dart';

import '../auth/session.dart';
import '../settings/app_settings.dart';
import 'background_sync.dart';
import 'sync_api.dart';
import 'sync_gate.dart';
import 'sync_service.dart';

/// Why a sync did not finish.
enum SyncProblem {
  /// The server could not be reached. Records stay on the phone.
  offline,

  /// Signed in without the internet, or the sign-in has expired.
  needsSignIn,

  /// The server answered with an error ([SyncOutcome.errorCode]).
  failed,
}

/// The result of one sync attempt.
class SyncOutcome {
  const SyncOutcome.done(SyncReport this.report)
      : problem = null,
        errorCode = null;

  const SyncOutcome.problem(SyncProblem this.problem, [this.errorCode]) : report = null;

  final SyncReport? report;
  final SyncProblem? problem;
  final String? errorCode;
}

class AutoSync extends ChangeNotifier {
  /// With [enabled] false (tests), sync runs only when [run] is called.
  AutoSync({
    required this._session,
    this.enabled = true,
    this.every = const Duration(minutes: 2),
    this.afterSave = const Duration(seconds: 3),
    this.pullEvery = const Duration(minutes: 10),
    this._settings,
    this._gate,
    this._scheduler = const NoBackgroundScheduler(),
    Stream<bool>? connectivity,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _session.addListener(_onSessionChanged);
    if (enabled && connectivity != null) _network = connectivity.listen(_onNetworkChanged);
    _onSessionChanged();
  }

  final Session _session;
  final bool enabled;

  /// Time between checks while the app is open: the retry interval.
  final Duration every;

  /// Wait after a save, so a burst of saves goes in one push.
  final Duration afterSave;

  /// With nothing waiting, how often to pull the area's changes (and refresh
  /// the tokens, which brings a new area or a deactivation).
  final Duration pullEvery;

  final AppSettings? _settings;
  final SyncGate? _gate;
  final BackgroundScheduler _scheduler;
  final DateTime Function() _clock;

  bool _started = false;
  bool _appOpen = false;
  Timer? _periodic;
  Timer? _soon;
  Timer? _renewOpen;
  StreamSubscription<void>? _outboxWatch;
  StreamSubscription<bool>? _network;
  AppLifecycleListener? _lifecycle;
  bool? _hadNetwork;

  /// Whether the last attempt reached the server; null before the first one.
  bool? get online => _online;
  bool? _online;

  /// The last attempt's result, automatic or not.
  SyncOutcome? get lastOutcome => _lastOutcome;
  SyncOutcome? _lastOutcome;

  /// Syncs now, or joins a sync that is already running. Waits for a background
  /// sync to finish first. Network problems are reported in the outcome, never
  /// thrown.
  Future<SyncOutcome> run() async {
    _soon?.cancel();
    SyncOutcome outcome;
    try {
      await _gate?.waitForBackground();
      outcome = SyncOutcome.done(await _session.sync());
      _online = true;
    } on NeedsOnlineSignIn {
      outcome = const SyncOutcome.problem(SyncProblem.needsSignIn);
    } on ApiException catch (error) {
      _online = true;
      outcome = SyncOutcome.problem(SyncProblem.failed, error.code);
    } on Object catch (error) {
      if (!isNetworkError(error)) rethrow;
      _online = false;
      outcome = const SyncOutcome.problem(SyncProblem.offline);
    }
    _lastOutcome = outcome;
    notifyListeners();
    return outcome;
  }

  // An automatic attempt: nothing to report to anyone if it fails, the next
  // one retries.
  void _runQuietly() {
    if (!_started) return;
    run().catchError((Object error) {
      debugPrint('Automatic sync failed: $error');
      return const SyncOutcome.problem(SyncProblem.failed);
    });
  }

  // The periodic check: sync while records wait or the last attempt failed,
  // otherwise only every [pullEvery].
  Future<void> _tick() async {
    final data = _session.data;
    if (!_started || data == null) return;
    try {
      final waiting = await data.db.pendingCount() > 0;
      final lastSync = await data.db.lastSyncAt();
      final due = lastSync == null || _clock().difference(lastSync).abs() >= pullEvery;
      if (!waiting && !due && _lastOutcome?.problem == null) return;
    } on Object catch (_) {
      return; // the database is closing
    }
    _runQuietly();
  }

  void _onNetworkChanged(bool hasNetwork) {
    final cameBack = hasNetwork && _hadNetwork == false;
    _hadNetwork = hasNetwork;
    if (!cameBack) return;
    if (_started) {
      _soon?.cancel();
      _soon = Timer(const Duration(seconds: 2), _runQuietly);
    }
  }

  void _onSessionChanged() {
    if (!enabled) return;
    _setAppOpen(_session.isUnlocked);
    final data = _session.data;
    final shouldRun = _session.isUnlocked && _session.canSync && data != null;
    if (shouldRun == _started) return;
    if (!shouldRun) {
      _stop();
      return;
    }
    _started = true;
    _periodic = Timer.periodic(every, (_) => _tick());
    _lifecycle = AppLifecycleListener(onResume: _runQuietly, onHide: _handOverIfWaiting);
    _outboxWatch = data.db.tableUpdates(TableUpdateQuery.onTable(data.db.outbox)).listen((_) => _onOutboxChanged());
    _soon = Timer(afterSave, _runQuietly); // what waited while the app was locked
  }

  // The open app tells background sync to leave the work to it (SyncGate).
  void _setAppOpen(bool open) {
    final gate = _gate;
    if (gate == null || open == _appOpen) return;
    _appOpen = open;
    _renewOpen?.cancel();
    _renewOpen = null;
    if (open) {
      unawaited(gate.markAppOpen());
      _renewOpen = Timer.periodic(SyncGate.renewEvery, (_) => unawaited(gate.markAppOpen()));
    } else {
      unawaited(gate.clearAppOpen().then((_) => _handOverIfWaiting()));
    }
  }

  // Records still waiting when the app locks or goes to the background: Android
  // sends them as soon as there is a network (background_sync.dart).
  Future<void> _handOverIfWaiting() async {
    final data = _session.data;
    int waiting;
    try {
      if (data != null) {
        waiting = await data.db.pendingCount();
      } else {
        await _session.closed; // closing the database saves the count
        waiting = _settings?.pendingRecords ?? 0;
      }
    } on Object catch (_) {
      waiting = _settings?.pendingRecords ?? 0;
    }
    if (waiting == 0) return;
    try {
      await _scheduler.syncWhenOnline();
    } on Object catch (error) {
      debugPrint('Could not schedule background sync: $error');
    }
  }

  // A record was saved (or a sync removed sent records): sync soon if anything
  // is waiting.
  Future<void> _onOutboxChanged() async {
    final data = _session.data;
    if (!_started || data == null) return;
    try {
      if (await data.db.pendingCount() == 0) return;
    } on Object catch (_) {
      return; // the database is closing
    }
    if (!_started) return;
    _soon?.cancel();
    _soon = Timer(afterSave, _runQuietly);
  }

  void _stop() {
    _started = false;
    _periodic?.cancel();
    _soon?.cancel();
    _lifecycle?.dispose();
    _outboxWatch?.cancel();
    _periodic = null;
    _soon = null;
    _lifecycle = null;
    _outboxWatch = null;
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _network?.cancel();
    _renewOpen?.cancel();
    _stop();
    super.dispose();
  }
}
