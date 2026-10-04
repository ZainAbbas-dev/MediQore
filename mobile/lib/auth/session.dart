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
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/app_database.dart';
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
    required this._db,
    required this._api,
    required this._sync,
    required this._settings,
    this.autoLockAfter = const Duration(minutes: 5),
    this.passwordIterations = PasswordKey.defaultIterations,
  });

  final AppDatabase _db;
  final SyncApi _api;
  final SyncService _sync;
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

  // Kept only between a sign-in that needs a code and the code check.
  String? _pendingUsername;
  String? _pendingPassword;

  bool get isUnlocked => _user != null;
  SessionUser? get user => _user;

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
      if (_isNetworkError(error)) return _signInOffline(local, username, password);
      rethrow;
    }
  }

  /// Checks the one-time code for this phone, using the credentials from the
  /// sign-in that asked for it.
  Future<SignInResult> verifyCode(String code) async {
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
      if (_isNetworkError(error)) return SignInResult.needsInternet;
      rethrow;
    }
  }

  void cancelCode() {
    _pendingUsername = null;
    _pendingPassword = null;
  }

  /// Pushes and pulls with the session's tokens, refreshing them if needed.
  Future<SyncReport> sync() => _withToken(_sync.syncNow);

  /// Forgets the tokens and the key; the LHW signs in again to continue.
  void lock([SessionNotice? reason = SessionNotice.lockedAfterInactivity]) {
    if (!isUnlocked) return;
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _key = null;
    notice = reason;
    notifyListeners();
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
      if (await _db.pendingCount() > 0) {
        try {
          await _api.logout(tokens.refreshToken); // the tokens just issued are not used
        } on Object catch (_) {
          // Best effort: the token expires on its own.
        }
        return SignInResult.otherUserHasUnsyncedData;
      }
      await _db.clearAllData();
    }

    // Reuse the stored key when the password is the same. A new password (for
    // example after an admin reset) gets a new key; once the database is
    // encrypted (M3 FE-2), data under the old key cannot be read (LI-8).
    var key = sameUser ? await local.key.unlock(password) : null;
    var passwordKey = sameUser ? local.key : null;
    if (key == null) {
      final (created, derived) = await PasswordKey.create(password, iterations: passwordIterations);
      passwordKey = created;
      key = derived;
    }
    await LocalAccount(user: user, key: passwordKey!).write(_settings.store);

    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    _key = key;

    final areaChanged = sameUser && local.user.areaId != user.areaId;
    if (!sameUser || areaChanged) {
      // First sign-in, or an admin moved the LHW to another area (M1 FE-1, FE-3):
      // send what is waiting, then download only the (new) area's records.
      _downloading = true;
      notifyListeners();
      try {
        if (areaChanged) {
          await _sync.push(tokens.accessToken);
          await _db.clearAreaData();
        }
        await _sync.pull(tokens.accessToken);
      } on Object catch (error) {
        if (!_isNetworkError(error) && error is! ApiException) rethrow;
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

  static bool _isNetworkError(Object error) =>
      error is SocketException || error is http.ClientException || error is TimeoutException || error is HandshakeException;
}
