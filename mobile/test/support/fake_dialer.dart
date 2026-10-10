import 'package:mediqore/phone/phone_dialer.dart';

/// Records the numbers the app asked the dialer to call (M1 FE-2).
class FakeDialer implements PhoneDialer {
  final List<String> dialled = [];

  /// When false, the phone "could not open the dialer".
  bool works = true;

  @override
  Future<bool> dial(String number) async {
    dialled.add(number);
    return works;
  }
}
