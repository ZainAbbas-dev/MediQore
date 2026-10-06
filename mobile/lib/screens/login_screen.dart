// M1 FE-2: login screen (P0-7 screen 1), with the language button (M1 FE-4)
// at the top.
// The first sign-in on a phone is online; later ones also work offline.
// A test build also shows the server address, which testers can change.
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../auth/session.dart';
import '../build_flags.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/app_cards.dart';
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
    final theme = Theme.of(context);
    final notice = switch (_session.notice) {
      SessionNotice.lockedAfterInactivity => l10n.loginLockedNotice,
      SessionNotice.deactivated => l10n.loginDeactivated,
      SessionNotice.signedOut => l10n.loginSignedOutNotice,
      null => null,
    };
    final message = _error ?? notice;

    return Scaffold(
      body: ListenableBuilder(
        listenable: _session,
        // A short page: everything is built at once, also on a small phone.
        builder: (context, _) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(services: widget.services),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.loginTitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        AppTextField(label: l10n.loginUsername, controller: _username, ltr: true),
                        const SizedBox(height: 12),
                        AppTextField(label: l10n.fieldPassword, controller: _password, obscureText: true, ltr: true),
                        const SizedBox(height: 16),
                        if (message != null) ...[
                          NoticeCard(text: message, warning: _error != null || _session.notice == SessionNotice.deactivated),
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
                ),
              ),
              if (widget.showServerSetting)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.dns),
                      title: Text(l10n.loginServerLabel, style: theme.textTheme.bodyMedium),
                      // The address reads left to right in both languages.
                      subtitle: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(widget.services.serverAddress, textDirection: TextDirection.ltr),
                      ),
                      trailing: TextButton(onPressed: _busy ? null : _changeServer, child: Text(l10n.loginServerChange)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The teal header: the app's name, what it is for, and the language button.
class _Header extends StatelessWidget {
  const _Header({required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: LanguageToggle(settings: services.settings),
              ),
              const SizedBox(height: 8),
              const CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                child: Icon(Icons.health_and_safety, size: 44, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.appTitle,
                style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              Text(
                l10n.appTagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
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
