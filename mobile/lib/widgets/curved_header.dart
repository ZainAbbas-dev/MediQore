import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The teal header with rounded bottom corners from the final design (P0-7):
/// a back button when the screen can go back, a title, an optional subtitle,
/// actions such as the settings gear, and optional content under the title.
///
/// [overlap] adds room at the bottom so the first card of the screen can sit
/// over the header's lower edge (give that card a negative top offset of the
/// same size). Layout follows the language: right to left in Urdu.
class CurvedHeader extends StatelessWidget {
  const CurvedHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.child,
    this.overlap = 0,
    this.showBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Extra content under the title, for example a patient's name and ID.
  final Widget? child;

  /// Room left at the bottom for a card that overlaps the header.
  final double overlap;

  /// Shows the back button; by default only when the screen can go back.
  final bool? showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = showBack ?? ModalRoute.of(context)?.canPop ?? false;
    final subtitleText = subtitle;
    return Semantics(
      container: true,
      header: true,
      child: Material(
        color: AppColors.primary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.headerRadius)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(12, 8, 12, 16 + overlap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (canPop) ...[
                      HeaderIconButton(
                        icon: const BackButtonIcon(),
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 8),
                    ] else
                      const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          if (subtitleText != null)
                            Text(
                              subtitleText,
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                            ),
                        ],
                      ),
                    ),
                    for (final action in actions) ...[const SizedBox(width: 8), action],
                  ],
                ),
                if (child != null) ...[const SizedBox(height: 12), child!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round icon button for the teal header: white icon on a translucent white circle.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      color: Colors.white,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        minimumSize: const Size(48, 48),
      ),
    );
  }
}
