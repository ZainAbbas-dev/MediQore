// M1 FE-2, FE-3: sign in again online with the password on this activated
// phone. Needed when the refresh token stopped working (a password reset, or
// a month without a sync) or after a deactivated account was reactivated.
// The records and the PIN stay as they are.
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_cards.dart';
import '../widgets/curved_header.dart';
import '../widgets/form_fields.dart';
import '../widgets/large_button.dart';
import 'activation_screen.dart' show signInMessage;

class SignInAgainScreen extends StatefulWidget {
  const SignInAgainScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<SignInAgainScreen> createState() => _SignInAgainScreenState();
}

class _SignInAgainScreenState extends State<SignInAgainScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn(AppLocalizations l10n) async {
    if (_password.text.isEmpty) {
      setState(() => _error = l10n.loginWrongPassword);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await widget.services.session.signInAgain(_password.text);
    if (!mounted) return;
    if (result == SignInResult.signedIn) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.signInAgainDone)));
      navigator.pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = signInMessage(l10n, result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = widget.services.session.account?.user;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CurvedHeader(title: l10n.homeSignInAgainButton, subtitle: user?.fullName),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.signInAgainIntro, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 12),
                      if (user != null) InfoRow(l10n.loginUsername, user.username, ltr: true),
                      const SizedBox(height: 12),
                      AppTextField(label: l10n.fieldPassword, controller: _password, obscureText: true, ltr: true),
                      const SizedBox(height: 12),
                      if (_error != null) ...[NoticeCard(text: _error!, warning: true), const SizedBox(height: 12)],
                      if (_busy) ...[
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 12),
                      ],
                      LargeButton(
                        label: l10n.signInButton,
                        icon: Icons.login,
                        onPressed: _busy ? null : () => _signIn(l10n),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
