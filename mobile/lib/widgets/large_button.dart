import 'package:flutter/material.dart';

/// Full-width button with a large touch target for field use (M3 FE-1).
/// Size and text style come from the app theme.
class LargeButton extends StatelessWidget {
  const LargeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
  });

  final String label;

  /// Disabled when null.
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Outlined style for the less important action, for example Cancel.
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, textAlign: TextAlign.center);
    final iconWidget = icon == null ? null : Icon(icon, size: 28);

    if (secondary) {
      return iconWidget == null
          ? OutlinedButton(onPressed: onPressed, child: text)
          : OutlinedButton.icon(onPressed: onPressed, icon: iconWidget, label: text);
    }
    return iconWidget == null
        ? FilledButton(onPressed: onPressed, child: text)
        : FilledButton.icon(onPressed: onPressed, icon: iconWidget, label: text);
  }
}
