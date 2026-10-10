// M1 FE-2: the lock screen's emergency call to the supervisor. The phone's
// dialer opens with the number filled in, so a lock never blocks an escalation.
import 'package:url_launcher/url_launcher.dart';

abstract interface class PhoneDialer {
  /// Opens the dialer with [number]; false if the phone could not.
  Future<bool> dial(String number);
}

/// The phone's dialer, through a `tel:` link (url_launcher).
class UrlLauncherDialer implements PhoneDialer {
  const UrlLauncherDialer();

  @override
  Future<bool> dial(String number) async {
    final digits = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return false;
    try {
      return await launchUrl(Uri(scheme: 'tel', path: digits));
    } on Object catch (_) {
      return false;
    }
  }
}
