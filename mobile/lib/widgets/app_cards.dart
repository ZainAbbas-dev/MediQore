// The app's shared layout pieces: cards with a heading, label and value rows,
// sync status chips and notices. Screens use
// these so every screen looks the same in Urdu and English.
import 'package:flutter/material.dart';

import '../data/patient_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'sync_status_text.dart';

/// A white card with a heading (and an optional icon) above its content.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, this.icon, required this.children, this.spacing = 12});

  final String title;
  final IconData? icon;
  final List<Widget> children;

  /// Space between the children.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[Icon(icon, color: theme.colorScheme.primary, size: 22), const SizedBox(width: 8)],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final (index, child) in children.indexed) ...[if (index > 0) SizedBox(height: spacing), child],
          ],
        ),
      ),
    );
  }
}

/// A label with its value on one line, or the value below the label when the
/// value is long. An empty value reads "not recorded".
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.ltr = false});

  final String label;
  final String? value;

  /// IDs, numbers and coordinates read left to right in both languages.
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final empty = value == null || value!.trim().isEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              empty ? l10n.fileNotRecorded : value!,
              textDirection: !empty && ltr ? TextDirection.ltr : null,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: empty ? theme.colorScheme.outline : null,
                fontWeight: empty ? null : FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small coloured label for a record's sync state: sent, waiting, refused,
/// or held for the supervisor (M3 FE-2).
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip(this.status, {super.key});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (foreground, background, icon) = switch (status) {
      SyncStatus.synced => (AppColors.statusSynced, AppColors.statusSyncedBackground, Icons.cloud_done),
      SyncStatus.waiting => (AppColors.statusPending, AppColors.statusPendingBackground, Icons.cloud_upload),
      SyncStatus.refused => (AppColors.statusProblem, AppColors.statusProblemBackground, Icons.error),
      SyncStatus.held => (AppColors.statusOffline, AppColors.statusOfflineBackground, Icons.hourglass_top),
    };
    return StatusPill(
      label: syncStatusText(l10n, status) ?? l10n.syncSent,
      icon: icon,
      foreground: foreground,
      background: background,
    );
  }
}

/// A rounded label with an icon, for states and short facts.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How a [NoticeCard] reads: plain information, something that needs
/// attention soon (amber), a problem (red) or a step that went well (green).
enum NoticeTone { info, attention, problem, success }

/// A notice inside a screen, in the colour of its [tone].
class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.text, this.tone = NoticeTone.info, this.icon});

  final String text;
  final NoticeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (foreground, background, defaultIcon) = switch (tone) {
      NoticeTone.info => (AppColors.statusOffline, AppColors.statusOfflineBackground, Icons.info_outline),
      NoticeTone.attention => (AppColors.statusPending, AppColors.statusPendingBackground, Icons.schedule),
      NoticeTone.problem => (AppColors.statusProblem, AppColors.statusProblemBackground, Icons.warning_amber),
      NoticeTone.success => (AppColors.statusSynced, AppColors.statusSyncedBackground, Icons.check_circle_outline),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foreground.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? defaultIcon, color: foreground, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The heading above a group of cards on a screen (final design 6 and 7:
/// "Today's work", "Language"): dark, bold, without an icon, so it does not
/// compete with the cards' own headings.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 10),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.text),
        ),
      ),
    );
  }
}

/// A soft teal panel with an info icon, for a short explanation under a form
/// (final design screens 1, 2 and 5).
class InfoPanel extends StatelessWidget {
  const InfoPanel({super.key, required this.text, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primaryDark, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primaryDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An empty list, said kindly: a soft icon and a line of text, centred (no
/// visits yet, no women registered).
class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primarySoft,
            child: Icon(icon, size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

/// A round badge with the first letter of a name.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.name, {super.key, this.radius = 24});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = name.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      child: Text(
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
        style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w600, height: 1.2),
      ),
    );
  }
}
