import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/auth/pin.dart';

void main() {
  test('a PIN is exactly six digits', () {
    expect(isPin('012345'), isTrue);
    expect(isPin('12345'), isFalse);
    expect(isPin('1234567'), isFalse);
    expect(isPin('12a456'), isFalse);
  });

  test('the verifier accepts the PIN only, survives storage and keeps no PIN', () async {
    final verifier = await PinVerifier.create('482913', iterations: 1000);
    final stored = verifier.encode();

    expect(stored, isNot(contains('482913')));
    final read = PinVerifier.decode(stored);
    expect(await read.check('482913'), isTrue);
    expect(await read.check('482914'), isFalse);
    expect(read.iterations, 1000);
  });

  test('each PIN gets its own salt', () async {
    final a = await PinVerifier.create('111111', iterations: 1000);
    final b = await PinVerifier.create('111111', iterations: 1000);
    expect(a.salt, isNot(b.salt));
    expect(a.verifier, isNot(b.verifier));
  });

  group('wrong-PIN waits (M1 FE-2)', () {
    final start = DateTime.utc(2026, 10, 10, 9);

    test('grow 30 s, 1 min, 5 min, then stay at 15 min', () {
      var attempts = PinAttempts.none;
      final delays = <Duration>[];
      for (var i = 0; i < 6; i++) {
        attempts = attempts.failedAt(start);
        delays.add(attempts.delay);
      }
      expect(delays, [
        const Duration(seconds: 30),
        const Duration(minutes: 1),
        const Duration(minutes: 5),
        const Duration(minutes: 15),
        const Duration(minutes: 15),
        const Duration(minutes: 15),
      ]);
    });

    test('count down from the last wrong PIN, and restart if the clock goes back', () {
      final attempts = PinAttempts.none.failedAt(start);
      expect(PinAttempts.none.waitAt(start), Duration.zero);
      expect(attempts.waitAt(start.add(const Duration(seconds: 12))), const Duration(seconds: 18));
      expect(attempts.waitAt(start.add(const Duration(minutes: 2))), Duration.zero);
      expect(attempts.waitAt(start.subtract(const Duration(days: 1))), const Duration(seconds: 30));
    });

    test('survive storage', () {
      final attempts = PinAttempts.none.failedAt(start).failedAt(start);
      final read = PinAttempts.decode(attempts.encode());
      expect(read.failures, 2);
      expect(read.lastFailure, start);
      expect(PinAttempts.decode(null).failures, 0);
    });
  });
}
