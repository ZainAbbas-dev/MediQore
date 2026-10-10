// M1 FE-2: offline PIN reset. The phone shows a 6-digit code; the LHW reads it
// to her supervisor, who enters it on the portal and reads back an 8-digit
// reply code. The phone checks the reply with the secret it received once at
// activation, without the internet, and the LHW sets a new PIN. Her records
// stay as they are.
//
// The formula is the API's (api/src/services/activation.service.js):
// HMAC-SHA256(secret, "mediqore/pin-reset/" + challenge), the first four bytes
// as an unsigned big-endian number, modulo 100000000, padded to 8 digits.
// Both sides test the same vector (test/auth/pin_reset_test.dart).
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// A new random 6-digit code for the supervisor.
String newResetChallengeCode([Random? random]) => (random ?? Random.secure()).nextInt(1000000).toString().padLeft(6, '0');

/// The reply code the portal gives for [challenge].
String resetReplyFor(List<int> secret, String challenge) {
  final digest = Hmac(sha256, secret).convert(utf8.encode('mediqore/pin-reset/$challenge')).bytes;
  final value = ByteData.sublistView(Uint8List.fromList(digest)).getUint32(0);
  return (value % 100000000).toString().padLeft(8, '0');
}

/// Whether [reply] (spaces allowed) is the supervisor's reply to [challenge].
bool isResetReply(List<int> secret, String challenge, String reply) {
  final typed = reply.replaceAll(RegExp(r'\s'), '');
  final expected = resetReplyFor(secret, challenge);
  if (typed.length != expected.length) return false;
  var diff = 0;
  for (var i = 0; i < expected.length; i++) {
    diff |= typed.codeUnitAt(i) ^ expected.codeUnitAt(i);
  }
  return diff == 0;
}

/// The secret as the API sends it (base64url without padding).
Uint8List decodeActivationSecret(String text) => base64Url.decode(base64Url.normalize(text));
