// M1 FE-2: the offline six-digit PIN. The phone keeps only a slow hash of it
// (PBKDF2-HMAC-SHA256 with a random salt, in the Keystore-backed secure
// store), never the PIN. Wrong PINs make the LHW wait longer each time: 30
// seconds, 1 minute, 5 minutes, then 15 minutes for every further wrong PIN.
// There is never a lockout that needs the internet: a forgotten PIN is reset
// with the supervisor's reply code (pin_reset.dart).
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'password_key.dart' show pbkdf2Sha256;

/// Exactly six digits.
bool isPin(String text) => RegExp(r'^\d{6}$').hasMatch(text);

/// The waits after the 1st, 2nd, 3rd and 4th wrong PIN in a row; every later
/// wrong PIN waits as long as the last one (M1 FE-2, final design screen 4).
const List<Duration> pinDelays = [
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(minutes: 15),
];

/// The salt, iteration count and a verifier (SHA-256 of the derived bytes).
/// The derived bytes are not used as a key: the database key is random and
/// independent of the PIN (LI-8).
class PinVerifier {
  const PinVerifier({required this.salt, required this.iterations, required this.verifier});

  /// Iterations for new PINs, stored with each verifier so it can change later.
  /// About a second on a low-cost phone; measure on the test phones before the
  /// field study.
  static const int defaultIterations = 60000;

  final Uint8List salt;
  final int iterations;
  final Uint8List verifier;

  /// A verifier for [pin] with a new random salt. Runs off the UI thread.
  static Future<PinVerifier> create(String pin, {int iterations = defaultIterations}) async {
    final random = Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
    return PinVerifier(salt: salt, iterations: iterations, verifier: await _hash(pin, salt, iterations));
  }

  /// Whether [pin] is the PIN. Runs off the UI thread.
  Future<bool> check(String pin) async => _equal(await _hash(pin, salt, iterations), verifier);

  String encode() =>
      jsonEncode({'salt': base64Encode(salt), 'iterations': iterations, 'verifier': base64Encode(verifier)});

  static PinVerifier decode(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    return PinVerifier(
      salt: base64Decode(json['salt'] as String),
      iterations: json['iterations'] as int,
      verifier: base64Decode(json['verifier'] as String),
    );
  }

  static Future<Uint8List> _hash(String pin, Uint8List salt, int iterations) => Isolate.run(
    () => Uint8List.fromList(sha256.convert(pbkdf2Sha256(utf8.encode(pin), salt, iterations, 32)).bytes),
  );

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

/// Wrong PINs in a row and when the last one was typed.
class PinAttempts {
  const PinAttempts({this.failures = 0, this.lastFailure});

  static const PinAttempts none = PinAttempts();

  final int failures;
  final DateTime? lastFailure;

  /// The wait after these wrong PINs: zero before the first.
  Duration get delay => failures == 0 ? Duration.zero : pinDelays[min(failures, pinDelays.length) - 1];

  /// How long the LHW still has to wait at [now]. If the phone's clock was
  /// set back before the last wrong PIN, the whole delay applies again.
  Duration waitAt(DateTime now) {
    final last = lastFailure;
    if (failures == 0 || last == null) return Duration.zero;
    if (now.isBefore(last)) return delay;
    final left = last.add(delay).difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  PinAttempts failedAt(DateTime now) => PinAttempts(failures: failures + 1, lastFailure: now);

  String encode() => jsonEncode({'failures': failures, 'lastFailure': lastFailure?.toUtc().toIso8601String()});

  static PinAttempts decode(String? text) {
    if (text == null || text.isEmpty) return none;
    final json = jsonDecode(text) as Map<String, dynamic>;
    final last = json['lastFailure'] as String?;
    return PinAttempts(failures: json['failures'] as int, lastFailure: last == null ? null : DateTime.parse(last));
  }
}
