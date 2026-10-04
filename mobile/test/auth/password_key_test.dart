import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/auth/password_key.dart';

String hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  // Reference values from Python's hashlib.pbkdf2_hmac('sha256', ...); the first
  // two are also the PBKDF2-HMAC-SHA256 test vectors of RFC 7914, section 11.
  test('PBKDF2-HMAC-SHA256 matches the reference values', () {
    expect(
      hex(pbkdf2Sha256(utf8.encode('passwd'), utf8.encode('salt'), 1, 64)),
      '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
      '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
    );
    expect(
      hex(pbkdf2Sha256(utf8.encode('Password'), utf8.encode('NaCl'), 80000, 64)),
      '4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56'
      'a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d',
    );
    expect(
      hex(pbkdf2Sha256(utf8.encode('demo-password'), List.generate(16, (i) => i), 1000, 32)),
      '54da697a05dfeb9f9f3c655cfd056dab7b4349adf5034841777bf622fc784a0b',
    );
  });

  test('a password key unlocks with the right password only, and survives storage', () async {
    final (key, derived) = await PasswordKey.create('demo-password', iterations: 1000);
    final stored = PasswordKey.fromJson(jsonDecode(jsonEncode(key.toJson())) as Map<String, dynamic>);

    expect(await stored.unlock('demo-password'), derived);
    expect(await stored.unlock('wrong'), isNull);
    expect(key.toJson().values.join(), isNot(contains(hex(derived))), reason: 'the key itself is never stored');
  });

  test('every key gets its own salt', () async {
    final (a, _) = await PasswordKey.create('same', iterations: 10);
    final (b, _) = await PasswordKey.create('same', iterations: 10);
    expect(a.salt, isNot(b.salt));
  });
}
