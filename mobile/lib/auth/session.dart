// M1 FE-2, FE-3: sign-in on the phone, online and offline.
// - The first sign-in on a phone needs the internet. The server checks the
//   password; a new phone also needs its one-time code (decision 0002).
// - After an online sign-in the phone keeps a password key (PBKDF2) and the
//   account, so later sign-ins work without the internet (LI-8).
// - Tokens stay in memory only. Sync uses them and refreshes them when the
//   access token has expired.
// - Lock (inactivity or the Lock button) forgets the tokens and the key.
// - A deactivated account is refused at the next sync, and offline sign-in is
//   refused from then on.
// M3 FE-2, LI-8: the local database is encrypted with the password key. It is
// opened at sign-in and closed at lock, so it is only readable while unlocked.
// A new password means a new key: the old database cannot be read any more and
// is replaced by an empty one, filled again from the server.
import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/database_opener.dart';
import '../data/local_data.dart';
import '../settings/app_settings.dart';
import '../sync/sync_api.dart';
import '../sync/sync_service.dart';
import 'local_account.dart';
import 'password_key.dart';

/// The result of a sign-in or code check, for the login screens to explain.
enum SignInResult {
  signedIn,
  signedInOffline,
  needsCode,
  wrongPassword,
  needsInternet,
  deactivated,
  tooManyAttempts,
  deviceNotAllowed,
  otherUserHasUnsyncedData,
  codeInvalid,
  codeLocked,
  codeNotIssued,
  failed,
}

/// Why the session ended, shown on the login screen.
enum SessionNotice { lockedAfterInactivity, deactivated, signedOut }

/// Thrown when sync needs a fresh online sign-in (signed in offline, or the
/// refresh token has expired).
class NeedsOnlineSignIn implements Exception {}

class Session extends ChangeNotifier {
  Session({
    required this._opener,
    required this._api,
    required this._settings,
    this.autoLockAfter = const Duration(minutes: 5),
    this.passwordIterations = PasswordKey.defaultIterations,
  });

  final DatabaseOpener _opener;
  final SyncApi _api;
  final AppSettings _settings;

  /// Inactivity before the app locks itself (M1 FE-2).
  final Duration autoLockAfter;

  /// PBKDF2 iterations for new password keys; tests use fewer to run fast.
  final int passwordIterations;

  SessionUser? _user;
  String? _accessToken;
  String? _refreshToken;
  Uint8List? _key;
  bool _downloading = false;
  SessionNotice? notice;

  LocalData? _data;
  StreamSubscription<void>? _outboxWatch;
  Future<void>? _closing;

  /// Set when an online sign-in with a new password (an admin reset) found
  /// records that had not been synced: they were under the old key and are
  /// gone (LI-8). The home screen says so once.
  bool lostUnsyncedRecords = false;

  // Kept only between a sign-in that needs a code and the code check.
  String? _pendingUsername;
  String? _pendingPassword;

  bool get isUnlocked => _user != null;
  SessionUser? get user => _user;

  /// The open, decrypted database with its repositories; null while locked.
  LocalData? get data => _data;

  /// True while the first sign-in downloads the area's data.
  bool get isDownloading => _downloading;

  /// True when the app can sync without asking for the password again.
  bool get isOnlineSession => _accessToken != null;

  /// The username to prefill on the login screen.
  String? get lastUsername => LocalAccount.read(_settings.store)?.user.username;

  /// The key derived from the password, for the encrypted database (M3 FE-2).
  @visibleForTesting
  Uint8List? get passwordKey => _key;

  Future<SignInResult> signIn(String username, String password) async {
    await _closing; // a lock that is still closing the database
    username = username.trim();
    notice = null;
    final local = LocalAccount.read(_settings.store);
    try {
      final outcome = await _api.login(username, password, deviceId: _settings.deviceId);
      if (outcome.otpRequired) {
        _pendingUsername = username;
        _pendingPassword = password;
        return SignInResult.needsCode;
      }
      return await _completeOnline(outcome.tokens!, password, local);
    } on ApiException catch (error) {
      if (error.statusCode >= 500) return _signInOffline(local, username, password);
      return await _resultFor(error, local);
    } on Object catch (error) {
      if (isNetworkError(error)) return _signInOffline(local, username, password);
      rethrow;
    }
  }

  /// Checks the one-time code for this phone, using the credentials from the
  /// sign-in that asked for it.
  Future<SignInResult> verifyCode(String code) async {
    await _closing;
    final username = _pendingUsername;
    final password = _pendingPassword;
    if (username == null || password == null) return SignInResult.failed;
    try {
      final tokens = await _api.verifyOtp(username, password, deviceId: _settings.deviceId, code: code.trim());
      _pendingUsername = null;
      _pendingPassword = null;
      return await _completeOnline(tokens, password, LocalAccount.read(_settings.store));
    } on ApiException catch (error) {
      return switch (error.code) {
        'OTP_INVALID' => SignInResult.codeInvalid,
        'OTP_LOCKED' => SignInResult.codeLocked,
        'OTP_NOT_ISSUED' => SignInResult.codeNotIssued,
        _ => await _resultFor(error, LocalAccount.read(_settings.store)),
      };
    } on Object catch (error) {
      if (isNetworkError(error)) return SignInResult.needsInternet;
      rethrow;
    }
  }

  void cancelCode() {
    _pendingUsername = null;
    _pendingPassword = null;
  }

  /// Pushes and pulls with the session's tokens, refreshing them if needed.
  /// A sync that starts while another is running joins it, so the refresh
  /// token is never used twice (automatic sync, M3 FE-2, and the Sync button).
  Future<SyncReport> sync() => _syncing ??= _withToken((token) {
        final data = _data;
        if (data == null) throw NeedsOnlineSignIn();
        return data.sync.syncNow(token);
      }).whenComplete(() => _syncing = null);

  Future<SyncReport>? _syncing;

  /// Forgets the tokens and the key and closes the database; the LHW signs in
  /// again to continue.
  void lock([SessionNotice? reason = SessionNotice.lockedAfterInactivity]) {
    if (!isUnlocked) return;
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _key = null;
    lostUnsyncedRecords = false;
    final data = _data;
    _data = null;
    // In the root zone: closing must not depend on what triggered the lock
    // (the inactivity timer, a button, a test's fake clock).
    if (data != null) _closing = Zone.root.run(() => _closeData(data));
    notice = reason;
    notifyListeners();
  }

  /// Waits until a lock has finished closing the database.
  Future<void> get closed async => _closing;

  // Records waiting to be pushed, known without opening the database.
  Future<int> _pendingRecords() async => _settings.pendingRecords ?? await _opener.readablePendingCount() ?? 0;

  // Opens the database with [key]. Online, a database made with another key is
  // replaced by an empty one (its records cannot be read anyway); offline it is
  // an error. Returns the data and whether the database is new.
  Future<(LocalData, bool)> _openData(Uint8List key, {required bool replaceIfUnreadable}) async {
    var replaced = false;
    AppDatabase db;
    try {
      db = await _opener.open(key);
    } on WrongDatabaseKey {
      if (!replaceIfUnreadable) rethrow;
      await _opener.destroy();
      replaced = true;
      db = await _opener.open(key);
    }
    final data = LocalData(db, api: _api, deviceId: _settings.deviceId);
    await _savePending(data);
    _outboxWatch = db.tableUpdates(TableUpdateQuery.onTable(db.outbox)).listen((_) => _savePending(data));
    return (data, replaced);
  }

  Future<void> _savePending(LocalData data) async {
    try {
      await _settings.setPendingRecords(await data.db.pendingCount());
    } on Object catch (_) {
      // The database is closing; the count was saved before it closed.
    }
  }

  Future<void> _closeData(LocalData data) async {
    await _outboxWatch?.cancel();
    _outboxWatch = null;
    await _settings.setPendingRecords(await data.db.pendingCount());
    await _opener.close(data.db);
  }

  /// Revokes the refresh token on the server when online, then locks. The
  /// account and the records stay on the phone.
  Future<void> signOut() async {
    final refreshToken = _refreshToken;
    lock(SessionNotice.signedOut);
    if (refreshToken != null) {
      try {
        await _api.logout(refreshToken);
      } on Object catch (_) {
        // Offline: the token expires on its own.
      }
    }
  }

  Future<SignInResult> _completeOnline(AuthTokens tokens, String password, LocalAccount? local) async {
    final user = tokens.user;
    final sameUser = local != null && local.user.id == user.id;

    if (local != null && !sameUser) {
      if (await _pendingRecords() > 0) {
        try {
          await _api.logout(tokens.refreshToken); // the tokens just issued are not used
        } on Object catch (_) {
          // Best effort: the token expires on its own.
        }
        return SignInResult.otherUserHasUnsyncedData;
      }
      // The previous LHW's database is under her key: start an empty one.
      await _opener.destroy();
      await _settings.setPendingRecords(0);
    }

    // Reuse the stored key when the password is the same. A new password (for
    // example after an admin reset) gets a new key, and the database made with
    // the old key cannot be read any more (LI-8): it is replaced by an empty one.
    var key = sameUser ? await local.key.unlock(password) : null;
    var passwordKey = sameUser ? local.key : null;
    var lost = false;
    if (key == null) {
      if (sameUser) {
        lost = await _pendingRecords() > 0;
        await _opener.destroy();
        await _settings.setPendingRecords(0);
      }
      final (created, derived) = await PasswordKey.create(password, iterations: passwordIterations);
      passwordKey = created;
      key = derived;
    }
    await LocalAccount(user: user, key: passwordKey!).write(_settings.store);

    final (data, replaced) = await _openData(key, replaceIfUnreadable: true);
    _data = data;
    // Patient IDs continue after the highest number the server knows (M2 FE-1).
    await data.db.raisePatientCounter(user.lastPatientNumber ?? 0);

    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    _key = key;
    lostUnsyncedRecords = lost;

    final areaChanged = sameUser && local.user.areaId != user.areaId;
    final newDatabase = sameUser && (lost || replaced || passwordKey != local.key);
    if (!sameUser || areaChanged || newDatabase) {
      // First sign-in, or an admin moved the LHW to another area (M1 FE-1, FE-3):
      // send what is waiting, then download only the (new) area's records.
      _downloading = true;
      notifyListeners();
      try {
        if (areaChanged && !newDatabase) {
          await data.sync.push(tokens.accessToken);
          await data.db.clearAreaData();
        }
        await data.sync.pull(tokens.accessToken);
      } on Object catch (error) {
        if (!isNetworkError(error) && error is! ApiException) rethrow;
        // Signed in anyway; the next sync downloads the rest.
      } finally {
        _downloading = false;
      }
    }

    _user = user;
    notifyListeners();
    return SignInResult.signedIn;
  }

  Future<SignInResult> _signInOffline(LocalAccount? local, String username, String password) async {
    if (local == null || !local.isFor(username)) return SignInResult.needsInternet;
    if (local.deactivated) return SignInResult.deactivated;
    final key = await local.key.unlock(password);
    if (key == null) return SignInResult.wrongPassword;
    try {
      final (data, _) = await _openData(key, replaceIfUnreadable: false);
      _data = data;
    } on WrongDatabaseKey {
      return SignInResult.failed;
    }
    _key = key;
    _accessToken = null;
    _refreshToken = null;
    _user = local.user;
    notifyListeners();
    return SignInResult.signedInOffline;
  }

  Future<SignInResult> _resultFor(ApiException error, LocalAccount? local) async {
    switch (error.code) {
      case 'INVALID_CREDENTIALS':
        return SignInResult.wrongPassword;
      case 'ACCOUNT_INACTIVE':
        await _markDeactivated(local);
        return SignInResult.deactivated;
      case 'TOO_MANY_ATTEMPTS':
        return SignInResult.tooManyAttempts;
      case 'DEVICE_NOT_ALLOWED':
        return SignInResult.deviceNotAllowed;
      default:
        return SignInResult.failed;
    }
  }

  Future<void> _markDeactivated(LocalAccount? local) async {
    if (local != null && !local.deactivated) await local.copyWith(deactivated: true).write(_settings.store);
  }

  Future<T> _withToken<T>(Future<T> Function(String token) action) async {
    final access = _accessToken;
    if (access == null) throw NeedsOnlineSignIn();
    try {
      return await action(access);
    } on ApiException catch (error) {
      if (error.code == 'ACCOUNT_INACTIVE') {
        await _markDeactivated(LocalAccount.read(_settings.store));
        lock(SessionNotice.deactivated);
        rethrow;
      }
      if (error.statusCode != 401) rethrow;
    }
    final refreshToken = _refreshToken;
    if (refreshToken == null) throw NeedsOnlineSignIn();
    final AuthTokens tokens;
    try {
      tokens = await _api.refresh(refreshToken);
    } on ApiException catch (error) {
      _accessToken = null;
      _refreshToken = null;
      if (error.code == 'ACCOUNT_INACTIVE') {
        await _markDeactivated(LocalAccount.read(_settings.store));
        lock(SessionNotice.deactivated);
        rethrow;
      }
      throw NeedsOnlineSignIn();
    }
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    return action(tokens.accessToken);
  }
}
