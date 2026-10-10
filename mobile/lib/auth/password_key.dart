// PBKDF2-HMAC-SHA256, the slow hash behind the PIN check (pin.dart), and the
// password key of app versions before the Phase 1 revision. Those versions
// encrypted the database with a key derived from the password; activation
// uses it once to move an old database to the new random key (LegacyAccount,
// Session.completeActivation), so records not yet synced are kept.
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2 with HMAC-SHA256 (RFC 8018), checked against reference values in
/// test/auth/password_key_test.dart.
Uint8List pbkdf2Sha256(List<int> password, List<int> salt, int iterations, int length) {
  final hmac = Hmac(sha256, password);
  final out = BytesBuilder(copy: false);
  for (var block = 1; out.length < length; block++) {
    final first = Uint8List(salt.length + 4)..setAll(0, salt);
    ByteData.sublistView(first).setUint32(salt.length, block);
    var u = hmac.convert(first).bytes;
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var k = 0; k < t.length; k++) {
        t[k] ^= u[k];
      }
    }
    out.add(t);
  }
  return Uint8List.sublistView(out.toBytes(), 0, length);
}

/// The earlier versions' password key: the salt, the iteration count and a
/// verifier (SHA-256 of the key) were saved; the key itself never was.
class PasswordKey {
  const PasswordKey({required this.salt, required this.iterations, required this.verifier});

  /// Iterations for new keys. Stored with each key, so it can be changed later
  /// without breaking existing phones. About half a second on a development
  /// laptop; measure on the low-cost test phones before the field study.
  static const int defaultIterations = 120000;
  static const int keyLength = 32;

  final Uint8List salt;
  final int iterations;
  final Uint8List verifier;

  /// Derives a key for [password] with a new random salt. Runs off the UI thread.
  static Future<(PasswordKey, Uint8List)> create(String password, {int iterations = defaultIterations}) async {
    final random = Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
    final key = await _derive(password, salt, iterations);
    return (PasswordKey(salt: salt, iterations: iterations, verifier: _verifierOf(key)), key);
  }

  /// The key for [password] if it is the right password, otherwise null. Runs off the UI thread.
  Future<Uint8List?> unlock(String password) async {
    final key = await _derive(password, salt, iterations);
    return _equal(_verifierOf(key), verifier) ? key : null;
  }

  Map<String, Object> toJson() => {'salt': base64Encode(salt), 'iterations': iterations, 'verifier': base64Encode(verifier)};

  static PasswordKey fromJson(Map<String, dynamic> json) => PasswordKey(
    salt: base64Decode(json['salt'] as String),
    iterations: json['iterations'] as int,
    verifier: base64Decode(json['verifier'] as String),
  );

  static Future<Uint8List> _derive(String password, Uint8List salt, int iterations) =>
      Isolate.run(() => pbkdf2Sha256(utf8.encode(password), salt, iterations, keyLength));

  static Uint8List _verifierOf(Uint8List key) => Uint8List.fromList(sha256.convert(key).bytes);

  // Compares every byte, so the time taken does not reveal where they differ.
  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
