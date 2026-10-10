// M1 FE-2: activation, once per phone and online (final design screen 1):
// LHW ID, password and the admin's one-time activation code. The language
// button (M3 FE-3) is at the top, so the first sign-in can happen in either
// language. After activation the LHW creates her PIN; from then on the app
// opens with the PIN, without the internet.
// In a test build, pressing and holding the logo changes the server address.
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

/// The message for an activation or sign-in result, or null when there is none.
String? signInMessage(AppLocalizations l10n, SignInResult result) => switch (result) {
  SignInResult.activated || SignInResult.signedIn => null,
  SignInResult.wrongPassword => l10n.loginWrongPassword,
  SignInResult.codeInvalid => l10n.activateCodeInvalid,
  SignInResult.needsInternet => l10n.loginNeedsInternet,
  SignInResult.deactivated => l10n.loginDeactivated,
  SignInResult.tooManyAttempts => l10n.loginTooManyAttempts,
  SignInResult.deviceNotAllowed => l10n.loginDeviceNotAllowed,
  SignInResult.notAnLhwAccount => l10n.loginNotLhw,
  SignInResult.otherUserHasUnsyncedData => l10n.loginOtherUserData,
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

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key, required this.services, this.showServerSetting = testBuild});

  final AppServices services;

  /// Lets a tester change the server address by pressing and holding the
  /// logo. Nothing shows on the screen. On in a test build only (see
  /// `testBuild`); the settings show the address in use.
  final bool showServerSetting;

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  Session get _session => widget.services.session;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _activate(AppLocalizations l10n) async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty || _code.text.trim().isEmpty) {
      setState(() => _error = l10n.activateFillAll);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _session.activate(_username.text, _password.text, _code.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = signInMessage(l10n, result);
    });
    // On success the app shows the PIN screen instead of this one.
  }

  Future<void> _changeServer() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final address = await showDialog<String>(
      context: context,
      builder: (_) => _ServerDialog(current: widget.services.serverAddress),
    );
    if (address == null) return;
    await widget.services.setServerAddress(address);
    messenger.showSnackBar(SnackBar(content: Text(l10n.loginServerSaved(address))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final notice = _session.notice == SessionNotice.signedOut ? l10n.loginSignedOutNotice : null;
    final message = _error ?? notice;

    return Scaffold(
      // A short page: everything is built at once, also on a small phone.
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(services: widget.services, onLongPressLogo: widget.showServerSetting && !_busy ? _changeServer : null),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.activateTitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      AppTextField(label: l10n.loginUsername, controller: _username, ltr: true),
                      const SizedBox(height: 12),
                      AppTextField(label: l10n.fieldPassword, controller: _password, obscureText: true, ltr: true),
                      const SizedBox(height: 12),
                      AppTextField(label: l10n.activateCodeLabel, controller: _code, ltr: true, maxLength: 9),
                      const SizedBox(height: 8),
                      if (message != null) ...[
                        NoticeCard(text: message, warning: _error != null),
                        const SizedBox(height: 12),
                      ],
                      if (_busy) ...[
                        Row(
                          children: [
                            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(l10n.activateBusy)),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      LargeButton(
                        label: l10n.activateButton,
                        icon: Icons.verified_user,
                        onPressed: _busy ? null : () => _activate(l10n),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.activateNote,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The teal header: the app's name, what it is for, and the language button.
class _Header extends StatelessWidget {
  const _Header({required this.services, this.onLongPressLogo});

  final AppServices services;

  /// Test builds only: pressing and holding the logo changes the server.
  final VoidCallback? onLongPressLogo;

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
              GestureDetector(
                onLongPress: onLongPressLogo,
                child: const CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.health_and_safety, size: 44, color: AppColors.primary),
                ),
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
