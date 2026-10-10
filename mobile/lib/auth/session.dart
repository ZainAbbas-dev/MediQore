// M1 FE-2, FE-3: access to the app on the phone.
// - Activation, once per phone and online: LHW ID, password and the admin's
//   one-time activation code. The LHW then creates a six-digit PIN.
// - After that the PIN unlocks the app without the internet. Wrong PINs make
//   her wait longer each time (pin.dart); a forgotten PIN is reset offline with
//   the supervisor's reply code (pin_reset.dart). The lock screen always offers
//   an emergency call to the supervisor.
// - The local database is encrypted with 256 random bits made on the phone and
//   kept wrapped by the Android Keystore (secure_store.dart), never derived
//   from the password or the PIN (M3 FE-2, LI-8). It is opened at unlock and
//   closed at lock. A password reset or a new PIN keeps every record.
// - Tokens: the refresh token is kept in the Keystore-backed store and the
//   access token in memory. They are refreshed at sync, which also brings the
//   LHW's area and supervisors up to date. If the refresh token stops working
//   (a password reset, or 30 days without a sync), she signs in again online
//   with her password, on the same phone.
// - A deactivated account is refused at the next sync: the app locks and the
//   PIN stops working until an online sign-in succeeds again.
// - Sign-out, only when nothing is waiting to sync, removes the account, the
//   keys and the records from the phone; it must then be activated again.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/database_opener.dart';
import '../data/local_data.dart';
import '../settings/app_settings.dart';
import '../sync/sync_api.dart';
import '../sync/sync_service.dart';
import 'local_account.dart';
import 'pin.dart';
import 'pin_reset.dart';
import 'secure_store.dart';

/// Which screen the app shows.
enum SessionStage {
  /// No account on this phone: the activation screen.
  activation,

  /// Activated online; the LHW now creates her PIN.
  createPin,

  /// The lock screen: the PIN opens the app.
  locked,

  /// The app is open.
  unlocked,
}

/// The result of an activation or an online sign-in, for the screens to explain.
enum SignInResult {
  activated,
  signedIn,
  wrongPassword,
  codeInvalid,
  needsInternet,
  deactivated,
  tooManyAttempts,
  deviceNotAllowed,
  notAnLhwAccount,
  otherUserHasUnsyncedData,
  failed,
}

/// The result of a PIN typed on the lock screen.
enum UnlockResult { unlocked, wrongPin, mustWait, deactivated, failed }

class UnlockOutcome {
  const UnlockOutcome(this.result, [this.wait = Duration.zero]);

  final UnlockResult result;

  /// How long the keypad stays disabled (after a wrong PIN, or while waiting).
  final Duration wait;
}

/// Why the session ended, shown on the lock or activation screen.
enum SessionNotice { lockedAfterInactivity, deactivated, signedOut }

/// Thrown when sync needs an online sign-in with the password (the refresh
/// token no longer works).
class NeedsOnlineSignIn implements Exception {}

/// Keys in the Keystore-backed [SecureStore].
abstract final class SecureKeys {
  static const String databaseKey = 'database_key';
  static const String activationSecret = 'activation_secret';
  static const String refreshToken = 'refresh_token';
  static const String pin = 'pin';
  static const String pinAttempts = 'pin_attempts';

  static const List<String> all = [databaseKey, activationSecret, refreshToken, pin, pinAttempts];
}

// An activation that succeeded on the server; kept in memory until the PIN is
// created, then saved. If the app closes in between, nothing was saved and the
// LHW needs a new activation code.
class _PendingActivation {
  _PendingActivation(this.tokens, this.password);

  final AuthTokens tokens;
  final String password;
}

class Session extends ChangeNotifier {
  Session({
    required this._opener,
    required this._api,
    required this._settings,
    required this._secure,
    this.autoLockAfter = const Duration(minutes: 5),
    this.pinIterations = PinVerifier.defaultIterations,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now,
       _account = LocalAccount.read(_settings.store);

  final DatabaseOpener _opener;
  final SyncApi _api;
  final AppSettings _settings;
  final SecureStore _secure;
  final DateTime Function() _now;

  /// Inactivity before the app locks itself (M1 FE-2).
  final Duration autoLockAfter;

  /// PBKDF2 iterations for new PINs; tests use fewer to run fast.
  final int pinIterations;

  LocalAccount? _account;
  _PendingActivation? _pending;
  SessionUser? _user;
  String? _accessToken;
  String? _refreshToken;
  bool _downloading = false;
  bool _resetVerified = false;
  SessionNotice? notice;

  LocalData? _data;
  StreamSubscription<void>? _outboxWatch;
  Future<void>? _closing;
  Future<SyncReport>? _syncing;

  /// Set when activation could not keep the records of an earlier app version
  /// that were not synced (its password had changed). The home screen says so.
  bool lostUnsyncedRecords = false;

  SessionStage get stage => _user != null
      ? SessionStage.unlocked
      : _pending != null
      ? SessionStage.createPin
      : _account != null
      ? SessionStage.locked
      : SessionStage.activation;

  bool get isUnlocked => _user != null;
  SessionUser? get user => _user;

  /// The account this phone is activated for, also while locked (the lock
  /// screen's greeting and emergency call); null before activation.
  LocalAccount? get account => _account;

  /// Who is activating, between activation and the new PIN.
  SessionUser? get activatingUser => _pending?.tokens.user;

  /// The open, decrypted database with its repositories; null while locked.
  LocalData? get data => _data;

  /// True while activation downloads the area's records.
  bool get isDownloading => _downloading;

  /// True when the app can sync without asking for the password again.
  bool get canSync => _refreshToken != null;

  /// M1 FE-2: activates this phone. On success the stage moves to
  /// [SessionStage.createPin]; nothing is saved until the PIN is created.
  Future<SignInResult> activate(String username, String password, String code) async {
    await _closing;
    notice = null;
    final AuthTokens tokens;
    try {
      tokens = await _api.activate(username.trim(), password, code: code.trim(), deviceId: _settings.deviceId);
    } on ApiException catch (error) {
      return _resultFor(error);
    } on Object catch (error) {
      if (isNetworkError(error)) return SignInResult.needsInternet;
      rethrow;
    }
    if (tokens.activationSecret == null) return SignInResult.failed;
    // Records of another LHW from an earlier app version that never reached
    // the server: her account must sync them first (M1 FE-2).
    final legacy = LegacyAccount.read(_settings.store);
    if (legacy != null && legacy.user.id != tokens.user.id && await _pendingRecords() > 0) {
      unawaited(_revoke(tokens.refreshToken));
      return SignInResult.otherUserHasUnsyncedData;
    }
    _pending = _PendingActivation(tokens, password);
    notifyListeners();
    return SignInResult.activated;
  }

  /// Back to the activation screen without saving anything.
  void cancelActivation() {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    unawaited(_revoke(pending.tokens.refreshToken));
    notifyListeners();
  }

  /// Saves the activation with the new [pin]: a new random database key, the
  /// activation secret, the refresh token and the PIN check go into the
  /// Keystore-backed store, and the area's records are downloaded.
  Future<void> completeActivation(String pin) async {
    final pending = _pending;
    if (pending == null || !isPin(pin)) throw StateError('No activation waiting for a PIN');
    final tokens = pending.tokens;
    final user = tokens.user;
    final verifier = await PinVerifier.create(pin, iterations: pinIterations);
    final key = _randomKey();

    // An earlier app version's database (password key) keeps its records when
    // it belonged to the same LHW and her password still opens it. Anything
    // else on the phone is replaced by an empty database.
    final legacy = LegacyAccount.read(_settings.store);
    var kept = false;
    if (legacy != null && legacy.user.id == user.id) {
      final oldKey = await legacy.key.unlock(pending.password);
      if (oldKey != null) {
        try {
          await _opener.rekey(oldKey, key);
          kept = true;
        } on WrongDatabaseKey {
          // The file is not there or not readable: start empty.
        }
      }
      if (!kept) lostUnsyncedRecords = await _pendingRecords() > 0;
    }
    if (!kept) {
      await _opener.destroy();
      await _settings.setPendingRecords(0);
    }

    await _secure.write(SecureKeys.databaseKey, base64Encode(key));
    await _secure.write(SecureKeys.activationSecret, tokens.activationSecret!);
    await _secure.write(SecureKeys.refreshToken, tokens.refreshToken);
    await _secure.write(SecureKeys.pin, verifier.encode());
    await _secure.delete(SecureKeys.pinAttempts);
    final account = LocalAccount(user: user, supervisors: tokens.supervisors, dataAreaId: user.areaId);
    await account.write(_settings.store);
    await LegacyAccount.clear(_settings.store);
    _account = account;

    final data = await _openData(key);
    _data = data;
    await data.db.raisePatientCounter(user.lastPatientNumber ?? 0);
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;

    // The area's records (M1 FE-1): first send what an earlier version left.
    _downloading = true;
    notifyListeners();
    try {
      if (kept) await data.sync.push(tokens.accessToken);
      await data.sync.pull(tokens.accessToken);
    } on Object catch (error) {
      if (!isNetworkError(error) && error is! ApiException) rethrow;
      // Activated anyway; the next sync downloads the rest.
    } finally {
      _downloading = false;
    }
    _pending = null;
    _user = user;
    notifyListeners();
  }

  /// How long the keypad stays disabled after wrong PINs.
  Future<Duration> pinWait() async => (await _attempts()).waitAt(_now());

  /// M1 FE-2: opens the app with the PIN, without the internet.
  Future<UnlockOutcome> unlock(String pin) async {
    await _closing;
    final account = _account;
    if (account == null || isUnlocked) return const UnlockOutcome(UnlockResult.failed);
    if (account.deactivated) return const UnlockOutcome(UnlockResult.deactivated);
    final attempts = await _attempts();
    final wait = attempts.waitAt(_now());
    if (wait > Duration.zero) return UnlockOutcome(UnlockResult.mustWait, wait);
    final stored = await _secure.read(SecureKeys.pin);
    if (stored == null) return const UnlockOutcome(UnlockResult.failed);
    if (!await PinVerifier.decode(stored).check(pin)) {
      final failed = attempts.failedAt(_now());
      await _secure.write(SecureKeys.pinAttempts, failed.encode());
      return UnlockOutcome(UnlockResult.wrongPin, failed.delay);
    }
    await _secure.delete(SecureKeys.pinAttempts);
    return await _open(account) ? const UnlockOutcome(UnlockResult.unlocked) : const UnlockOutcome(UnlockResult.failed);
  }

  /// A new code for the supervisor (PIN reset, step 1).
  String newResetChallenge() {
    _resetVerified = false;
    return newResetChallengeCode();
  }

  /// Checks the supervisor's reply to [challenge] (PIN reset, step 2). When it
  /// is right, [resetPin] may set the new PIN.
  Future<bool> checkResetReply(String challenge, String reply) async {
    final secret = await _secure.read(SecureKeys.activationSecret);
    if (secret == null) return false;
    _resetVerified = isResetReply(decodeActivationSecret(secret), challenge, reply);
    return _resetVerified;
  }

  /// Saves the new PIN after a checked reply code, clears the wrong-PIN wait
  /// and opens the app. The records stay as they are.
  Future<bool> resetPin(String pin) async {
    final account = _account;
    if (!_resetVerified || account == null || !isPin(pin)) return false;
    _resetVerified = false;
    await _secure.write(SecureKeys.pin, (await PinVerifier.create(pin, iterations: pinIterations)).encode());
    await _secure.delete(SecureKeys.pinAttempts);
    if (account.deactivated) {
      notifyListeners();
      return true; // the PIN is new, but the lock screen explains the deactivation
    }
    return _open(account);
  }

  /// Settings → Change PIN: [current] must be the PIN in use.
  Future<bool> changePin(String current, String pin) async {
    final stored = await _secure.read(SecureKeys.pin);
    if (stored == null || !isPin(pin) || !await PinVerifier.decode(stored).check(current)) return false;
    await _secure.write(SecureKeys.pin, (await PinVerifier.create(pin, iterations: pinIterations)).encode());
    return true;
  }

  /// Signs in again online with the password on this activated phone, when
  /// the refresh token stopped working or the account was deactivated and is
  /// active again. Works while locked or unlocked; the PIN is unchanged.
  Future<SignInResult> signInAgain(String password) async {
    final account = _account;
    if (account == null) return SignInResult.failed;
    final AuthTokens tokens;
    try {
      tokens = await _api.login(account.user.username, password, deviceId: _settings.deviceId);
    } on ApiException catch (error) {
      return _resultFor(error);
    } on Object catch (error) {
      if (isNetworkError(error)) return SignInResult.needsInternet;
      rethrow;
    }
    await _useTokens(tokens);
    if (notice == SessionNotice.deactivated) notice = null;
    notifyListeners();
    return SignInResult.signedIn;
  }

  /// Pushes and pulls, refreshing the tokens first when needed. A sync that
  /// starts while another is running joins it, so the refresh token is never
  /// used twice (automatic sync, M3 FE-2, and the Sync button).
  Future<SyncReport> sync() => _syncing ??= _syncOnce().whenComplete(() => _syncing = null);

  Future<SyncReport> _syncOnce() async {
    if (_data == null) throw NeedsOnlineSignIn();
    try {
      if (_accessToken == null) await _refresh();
      return await _syncWith(_accessToken!);
    } on ApiException catch (error) {
      if (error.code == 'ACCOUNT_INACTIVE') {
        await _markDeactivated();
        rethrow;
      }
      if (error.statusCode != 401) rethrow;
    }
    await _refresh();
    return _syncWith(_accessToken!);
  }

  Future<SyncReport> _syncWith(String token) async {
    final data = _data;
    final account = _account;
    if (data == null || account == null) throw NeedsOnlineSignIn();
    // An admin moved the LHW to another area (M1 FE-3): send what is waiting,
    // then replace the old area's records with the new area's.
    if (account.user.areaId != account.dataAreaId) {
      await data.sync.push(token);
      await data.db.clearAreaData();
      await _saveAccount(account.copyWith(dataAreaId: account.user.areaId));
    }
    return data.sync.syncNow(token);
  }

  Future<void> _refresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) throw NeedsOnlineSignIn();
    final AuthTokens tokens;
    try {
      tokens = await _api.refresh(refreshToken);
    } on ApiException catch (error) {
      if (error.code == 'ACCOUNT_INACTIVE') {
        await _markDeactivated();
        rethrow;
      }
      if (error.statusCode != 401) rethrow;
      // Expired or revoked (a password reset): sign in again with the password.
      _accessToken = null;
      _refreshToken = null;
      await _secure.delete(SecureKeys.refreshToken);
      notifyListeners();
      throw NeedsOnlineSignIn();
    }
    await _useTokens(tokens);
  }

  // Keeps new tokens and the profile that came with them. While locked, the
  // tokens stay only in the secure store until the PIN opens the app.
  Future<void> _useTokens(AuthTokens tokens) async {
    await _secure.write(SecureKeys.refreshToken, tokens.refreshToken);
    final account = _account!;
    await _saveAccount(account.copyWith(user: tokens.user, supervisors: tokens.supervisors, deactivated: false));
    if (!isUnlocked) return;
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    _user = tokens.user;
    await _data?.db.raisePatientCounter(tokens.user.lastPatientNumber ?? 0);
  }

  Future<void> _saveAccount(LocalAccount account) async {
    await account.write(_settings.store);
    _account = account;
  }

  /// Forgets the access token and closes the database; the PIN opens the app
  /// again.
  void lock([SessionNotice? reason = SessionNotice.lockedAfterInactivity]) {
    if (!isUnlocked) return;
    _user = null;
    _accessToken = null;
    _refreshToken = null;
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

  /// Signs out of this phone: only when nothing is waiting to be sent, because
  /// the records, the account and the keys are removed. The phone gets a new
  /// installation ID and must be activated again. Returns false, changing
  /// nothing, while records are waiting.
  Future<bool> signOut() async {
    final data = _data;
    if (data == null || await data.db.pendingCount() > 0) return false;
    final refreshToken = _refreshToken;
    lock(SessionNotice.signedOut);
    await _closing;
    await _opener.destroy();
    await _settings.setPendingRecords(0);
    for (final key in SecureKeys.all) {
      await _secure.delete(key);
    }
    await LocalAccount.clear(_settings.store);
    _account = null;
    await _settings.newDeviceId();
    notifyListeners();
    if (refreshToken != null) await _revoke(refreshToken);
    return true;
  }

  // Opens the database for [account] with the key from the secure store.
  Future<bool> _open(LocalAccount account) async {
    final stored = await _secure.read(SecureKeys.databaseKey);
    if (stored == null) return false;
    try {
      _data = await _openData(base64Decode(stored));
    } on WrongDatabaseKey {
      return false;
    }
    _refreshToken = await _secure.read(SecureKeys.refreshToken);
    _accessToken = null;
    _user = account.user;
    notice = null;
    notifyListeners();
    return true;
  }

  Future<LocalData> _openData(Uint8List key) async {
    final AppDatabase db = await _opener.open(key);
    final data = LocalData(db, api: _api, deviceId: _settings.deviceId);
    await _savePending(data);
    _outboxWatch = db.tableUpdates(TableUpdateQuery.onTable(db.outbox)).listen((_) => _savePending(data));
    return data;
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

  // Records waiting to be pushed, known without opening the database.
  Future<int> _pendingRecords() async => _settings.pendingRecords ?? await _opener.readablePendingCount() ?? 0;

  Future<PinAttempts> _attempts() async => PinAttempts.decode(await _secure.read(SecureKeys.pinAttempts));

  Future<void> _markDeactivated() async {
    final account = _account;
    if (account != null && !account.deactivated) await _saveAccount(account.copyWith(deactivated: true));
    lock(SessionNotice.deactivated);
  }

  Future<void> _revoke(String refreshToken) async {
    try {
      await _api.logout(refreshToken);
    } on Object catch (_) {
      // Offline: the token expires on its own.
    }
  }

  SignInResult _resultFor(ApiException error) => switch (error.code) {
    'INVALID_CREDENTIALS' => SignInResult.wrongPassword,
    'ACTIVATION_CODE_INVALID' || 'VALIDATION_ERROR' => SignInResult.codeInvalid,
    'ACCOUNT_INACTIVE' => SignInResult.deactivated,
    'TOO_MANY_ATTEMPTS' => SignInResult.tooManyAttempts,
    'DEVICE_NOT_ALLOWED' || 'ACTIVATION_REQUIRED' => SignInResult.deviceNotAllowed,
    'APP_FOR_LHWS' => SignInResult.notAnLhwAccount,
    _ => error.statusCode >= 500 ? SignInResult.needsInternet : SignInResult.failed,
  };

  static Uint8List _randomKey() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
  }
}
