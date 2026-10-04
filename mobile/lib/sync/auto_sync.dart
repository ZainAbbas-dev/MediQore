// M3 FE-2: records sync automatically when the phone is online (roadmap,
// Offline sync: "outbox with retry ... background sync when online"). While the
// app is unlocked after an online sign-in, the phone syncs:
// - shortly after a record is saved;
// - every few minutes, which is also the retry after a failed attempt;
// - when the app comes back to the foreground.
// Nothing syncs while the app is locked: the database is then closed and
// encrypted with a key only the LHW's password gives (LI-8).
import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/widgets.dart';

import '../auth/session.dart';
import 'sync_api.dart';
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
  }) {
    _session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  final Session _session;
  final bool enabled;

  /// Time between attempts while the app is open: the retry interval.
  final Duration every;

  /// Wait after a save, so a burst of saves goes in one push.
  final Duration afterSave;

  bool _started = false;
  Timer? _periodic;
  Timer? _soon;
  StreamSubscription<void>? _outboxWatch;
  AppLifecycleListener? _lifecycle;

  /// Whether the last attempt reached the server; null before the first one.
  bool? get online => _online;
  bool? _online;

  /// The last attempt's result, automatic or not.
  SyncOutcome? get lastOutcome => _lastOutcome;
  SyncOutcome? _lastOutcome;

  /// Syncs now, or joins a sync that is already running. Network problems are
  /// reported in the outcome, never thrown.
  Future<SyncOutcome> run() async {
    _soon?.cancel();
    SyncOutcome outcome;
    try {
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

  void _onSessionChanged() {
    final data = _session.data;
    final shouldRun = enabled && _session.isUnlocked && _session.isOnlineSession && data != null;
    if (shouldRun == _started) return;
    if (!shouldRun) {
      _stop();
      return;
    }
    _started = true;
    _periodic = Timer.periodic(every, (_) => _runQuietly());
    _lifecycle = AppLifecycleListener(onResume: _runQuietly);
    _outboxWatch = data.db.tableUpdates(TableUpdateQuery.onTable(data.db.outbox)).listen((_) => _onOutboxChanged());
    _soon = Timer(afterSave, _runQuietly); // what waited while the app was locked
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
    _stop();
    super.dispose();
  }
}
