// M1 FE-2: login screen (P0-7 screen 1), with the language switch (M1 FE-4).
// The first sign-in on a phone is online; later ones also work offline.
// A test build also shows the server address, which testers can change.
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../auth/session.dart';
import '../build_flags.dart';
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

/// The address typed into the server dialog, without spaces or a final slash,
/// or null if it is not an http or https address. An address with no path gets
/// the API's `/api/v1`.
String? serverAddressFrom(String text) {
  var address = text.trim();
  while (address.endsWith('/')) {
    address = address.substring(0, address.length - 1);
  }
  final uri = Uri.tryParse(address);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) return null;
  return uri.path.isEmpty ? '$address/api/v1' : address;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.services, this.showServerSetting = testBuild});

  final AppServices services;

  /// Shows the server address and lets the tester change it. On in a test
  /// build only (see `testBuild`).
  final bool showServerSetting;

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

  Future<void> _changeServer() async {
    final address = await showDialog<String>(
      context: context,
      builder: (_) => _ServerDialog(current: widget.services.serverAddress),
    );
    if (address == null) return;
    await widget.services.setServerAddress(address);
    if (mounted) setState(() {});
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
            if (widget.showServerSetting) ...[
              const SizedBox(height: 32),
              Text(l10n.loginServerLabel, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              // The address reads left to right in both languages.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(widget.services.serverAddress, textDirection: TextDirection.ltr),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _busy ? null : _changeServer,
                  icon: const Icon(Icons.dns),
                  label: Text(l10n.loginServerChange),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Asks for a new server address; closes with the address, or null on Cancel.
class _ServerDialog extends StatefulWidget {
  const _ServerDialog({required this.current});

  final String current;

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final _address = TextEditingController(text: widget.current);
  bool _invalid = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _save() {
    final address = serverAddressFrom(_address.text);
    if (address == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.loginServerTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.loginServerHint),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: _invalid ? l10n.loginServerInvalid : null,
                errorMaxLines: 3,
              ),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.loginServerCancel)),
        FilledButton(onPressed: _save, child: Text(l10n.loginServerSave)),
      ],
    );
  }
}
