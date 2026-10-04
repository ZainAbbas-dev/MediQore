// M1 FE-2: login screen (P0-7 screen 1), with the language switch (M1 FE-4).
// The first sign-in on a phone is online; later ones also work offline.
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../widgets/form_fields.dart';
import '../widgets/language_switch.dart';
import '../widgets/large_button.dart';
import 'otp_screen.dart';

/// The message for a sign-in or code result, or null when there is none to show.
String? signInMessage(AppLocalizations l10n, SignInResult result) => switch (result) {
  SignInResult.signedIn || SignInResult.signedInOffline || SignInResult.needsCode => null,
  SignInResult.wrongPassword => l10n.loginWrongPassword,
  SignInResult.needsInternet => l10n.loginNeedsInternet,
  SignInResult.deactivated => l10n.loginDeactivated,
  SignInResult.tooManyAttempts => l10n.loginTooManyAttempts,
  SignInResult.deviceNotAllowed => l10n.loginDeviceNotAllowed,
  SignInResult.otherUserHasUnsyncedData => l10n.loginOtherUserData,
  SignInResult.codeInvalid => l10n.otpInvalid,
  SignInResult.codeLocked => l10n.otpLocked,
  SignInResult.codeNotIssued => l10n.otpNotIssued,
  SignInResult.failed => l10n.loginFailed,
};

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _username = TextEditingController(text: widget.services.session.lastUsername ?? '');
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Session get _session => widget.services.session;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn(AppLocalizations l10n) async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = l10n.loginWrongPassword);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _session.signIn(_username.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = signInMessage(l10n, result);
    });
    if (result == SignInResult.needsCode) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OtpScreen(services: widget.services)));
    }
    if (result == SignInResult.signedIn || result == SignInResult.signedInOffline) _password.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notice = switch (_session.notice) {
      SessionNotice.lockedAfterInactivity => l10n.loginLockedNotice,
      SessionNotice.deactivated => l10n.loginDeactivated,
      SessionNotice.signedOut => l10n.loginSignedOutNotice,
      null => null,
    };
    final message = _error ?? notice;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: ListenableBuilder(
        listenable: _session,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LanguageSwitch(settings: widget.services.settings),
            const SizedBox(height: 24),
            AppTextField(label: l10n.loginUsername, controller: _username, ltr: true),
            const SizedBox(height: 12),
            AppTextField(label: l10n.fieldPassword, controller: _password, obscureText: true, ltr: true),
            const SizedBox(height: 16),
            if (message != null) ...[
              Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
            ],
            if (_busy) ...[
              Row(
                children: [
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_session.isDownloading ? l10n.loginDownloading : l10n.loginSigningIn)),
                ],
              ),
              const SizedBox(height: 12),
            ],
            LargeButton(label: l10n.signInButton, icon: Icons.login, onPressed: _busy ? null : () => _signIn(l10n)),
          ],
        ),
      ),
    );
  }
}
