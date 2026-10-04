// M1 FE-2, decision 0002: a phone's first sign-in needs the one-time code an
// admin or supervisor issued for it on the portal.
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../widgets/form_fields.dart';
import '../widgets/large_button.dart';
import 'login_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify(AppLocalizations l10n) async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = l10n.otpInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.services.session.verifyCode(code);
    if (!mounted) return;
    if (result == SignInResult.signedIn) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = result == SignInResult.needsInternet ? l10n.otpNeedsInternet : signInMessage(l10n, result);
    });
  }

  void _back() {
    widget.services.session.cancelCode();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deviceId = widget.services.settings.deviceId;
    final session = widget.services.session;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.otpTitle)),
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.otpIntro, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(l10n.otpPhoneId(deviceId.substring(deviceId.length - 6))),
            const SizedBox(height: 16),
            AppTextField(
              label: l10n.otpCodeLabel,
              controller: _code,
              keyboardType: TextInputType.number,
              ltr: true,
              maxLength: 6,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_busy && session.isDownloading) ...[const SizedBox(height: 8), Text(l10n.loginDownloading)],
            const SizedBox(height: 16),
            LargeButton(label: l10n.otpVerifyButton, icon: Icons.verified_user, onPressed: _busy ? null : () => _verify(l10n)),
            const SizedBox(height: 12),
            LargeButton(label: l10n.otpBackButton, icon: Icons.arrow_back, secondary: true, onPressed: _busy ? null : _back),
          ],
        ),
      ),
    );
  }
}
