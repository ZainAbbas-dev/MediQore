// M1 FE-2: the lock screen (final design screens 3 and 4). The six-digit PIN
// opens the app without the internet. After a wrong PIN the keypad waits
// longer each time (30 seconds, 1 minute, 5 minutes, 15 minutes) with a
// countdown, but "Forgot PIN?" and the emergency call to the supervisor stay
// usable: there is never a lockout that needs the internet.
import 'dart:async';

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/emergency_call_button.dart';
import '../widgets/large_button.dart';
import '../widgets/pin_pad.dart';
import 'pin_reset_screen.dart';
import 'sign_in_again_screen.dart';

/// A wait as m:ss, for example 0:24 or 14:59.
String formatWait(Duration wait) {
  final seconds = (wait.inMilliseconds / 1000).ceil();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _entry = PinEntryController();
  Duration _wait = Duration.zero;
  bool _checking = false;
  String? _error;
  Timer? _ticker;

  Session get _session => widget.services.session;

  @override
  void initState() {
    super.initState();
    _session.pinWait().then(_startWait);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _entry.dispose();
    super.dispose();
  }

  void _startWait(Duration wait) {
    if (!mounted) return;
    _ticker?.cancel();
    setState(() => _wait = wait);
    if (wait <= Duration.zero) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final left = _wait - const Duration(seconds: 1);
      if (left <= Duration.zero) timer.cancel();
      setState(() => _wait = left <= Duration.zero ? Duration.zero : left);
    });
  }

  Future<void> _unlock(String pin) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _checking = true;
      _error = null;
    });
    final outcome = await _session.unlock(pin);
    if (!mounted) return;
    _entry.clear();
    setState(() => _checking = false);
    switch (outcome.result) {
      case UnlockResult.unlocked:
        break; // the app shows the home screen
      case UnlockResult.wrongPin || UnlockResult.mustWait:
        _startWait(outcome.wait);
      case UnlockResult.deactivated:
        setState(() {}); // the deactivation notice is shown from the account
      case UnlockResult.failed:
        setState(() => _error = l10n.lockFailed);
    }
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final account = _session.account;
    if (account == null) return const SizedBox.shrink(); // signed out; the app shows activation
    final deactivated = account.deactivated;
    final waiting = _wait > Duration.zero;
    final notice = switch (_session.notice) {
      SessionNotice.lockedAfterInactivity => l10n.loginLockedNotice,
      _ => null,
    };

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(name: account.user.fullName),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (deactivated) ...[
                    NoticeCard(text: l10n.loginDeactivated, warning: true),
                    const SizedBox(height: 12),
                    LargeButton(
                      label: l10n.homeSignInAgainButton,
                      icon: Icons.login,
                      onPressed: () => _open(SignInAgainScreen(services: widget.services)),
                    ),
                  ] else ...[
                    if (notice != null && !waiting && _error == null) ...[
                      NoticeCard(text: notice),
                      const SizedBox(height: 12),
                    ],
                    if (_error != null) ...[NoticeCard(text: _error!, warning: true), const SizedBox(height: 12)],
                    if (waiting) ...[_WaitCard(wait: _wait), const SizedBox(height: 16)],
                    if (_checking)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    PinEntry(controller: _entry, onComplete: _unlock, enabled: !waiting && !_checking),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _open(PinResetScreen(services: widget.services)),
                    child: Text(l10n.lockForgotPin, style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary)),
                  ),
                  const SizedBox(height: 16),
                  EmergencyCallButton(services: widget.services),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The teal header: the LHW's initial, the greeting and the instruction.
class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    return Material(
      color: AppColors.primary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.headerRadius)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Column(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                child: Text(
                  firstName.isEmpty ? '?' : firstName.characters.first.toUpperCase(),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.lockGreeting(firstName),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              Text(
                l10n.lockPrompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The wrong-PIN wait with its countdown (final design screen 4).
class _WaitCard extends StatelessWidget {
  const _WaitCard({required this.wait});

  final Duration wait;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const color = Color(0xFF8C1D18);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.statusProblemBackground,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Text(
                l10n.lockWrongPin,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
              Text(
                formatWait(wait),
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: color),
              ),
              Text(
                l10n.lockWaitNote,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
