import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/auth/pin_reset.dart';

void main() {
  // The API's shared test vector (api/tests/activation.test.js): the portal and
  // the phone must compute the same reply code.
  final vectorSecret = List.filled(32, 7);

  test('gives the same reply code as the portal for the shared test vector', () {
    expect(resetReplyFor(vectorSecret, '483917'), '26434093');
  });

  test('checks a reply with or without spaces, and refuses any other', () {
    expect(isResetReply(vectorSecret, '483917', '2643 4093'), isTrue);
    expect(isResetReply(vectorSecret, '483917', '26434094'), isFalse);
    expect(isResetReply(vectorSecret, '483917', '2643409'), isFalse);
    expect(isResetReply(vectorSecret, '483918', '26434093'), isFalse);
  });

  test('reads the secret as the API sends it (base64url without padding)', () {
    expect(decodeActivationSecret('BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc'), vectorSecret);
  });

  test('makes six-digit codes, zero-padded', () {
    expect(newResetChallengeCode(Random(1)), matches(RegExp(r'^\d{6}$')));
    for (var i = 0; i < 200; i++) {
      expect(newResetChallengeCode(), hasLength(6));
    }
  });
}
