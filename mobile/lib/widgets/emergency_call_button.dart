// M1 FE-2: "Emergency: call supervisor" on the lock screen and the PIN reset
// screen, so a lock never blocks an escalation. The numbers are the area
// supervisors' from the last activation, sign-in or sync.
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../auth/local_account.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

class EmergencyCallButton extends StatelessWidget {
  const EmergencyCallButton({super.key, required this.services, this.label});

  final AppServices services;

  /// The button text; "Emergency: call supervisor" by default.
  final String? label;

  Future<void> _call(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final supervisors = services.session.account?.supervisors ?? const <Supervisor>[];
    if (supervisors.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.emergencyNoNumber)));
      return;
    }
    final chosen = supervisors.length == 1
        ? supervisors.single
        : await showModalBottomSheet<Supervisor>(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.emergencyChooseSupervisor, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  for (final supervisor in supervisors)
                    ListTile(
                      leading: const Icon(Icons.call, color: AppColors.statusProblem),
                      title: Text(supervisor.name),
                      subtitle: Text(supervisor.phone, textDirection: TextDirection.ltr),
                      onTap: () => Navigator.of(context).pop(supervisor),
                    ),
                ],
              ),
            ),
          );
    if (chosen == null) return;
    if (!await services.dialer.dial(chosen.phone)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.emergencyCallFailed(chosen.phone))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      onPressed: () => _call(context),
      icon: const Icon(Icons.call, size: 26),
      label: Text(label ?? l10n.emergencyCallButton, textAlign: TextAlign.center),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.statusProblem,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.statusProblem, width: 2),
      ),
    );
  }
}
