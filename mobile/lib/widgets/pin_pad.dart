// M1 FE-2: the PIN entry of the final design (screens 2–4): six dots and a
// large keypad. Digits always read left to right, also in the Urdu layout.
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Six dots that fill as digits are typed.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled, this.length = 6});

  final int filled;
  final int length;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$filled / $length',
      excludeSemantics: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < length; i++)
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < filled ? AppColors.primary : Colors.transparent,
                  border: Border.all(color: i < filled ? AppColors.primary : AppColors.fieldBorder, width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Digits 1–9, 0 and Delete. [onDigit] and [onDelete] are ignored while
/// [enabled] is false (the wrong-PIN wait).
class PinKeypad extends StatelessWidget {
  const PinKeypad({super.key, required this.onDigit, required this.onDelete, this.enabled = true});

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget key(String digit) => _Key(
      onPressed: enabled ? () => onDigit(digit) : null,
      child: Text(digit, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
    );
    Widget row(List<Widget> keys) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          for (final (index, k) in keys.indexed) ...[if (index > 0) const SizedBox(width: 10), Expanded(child: k)],
        ],
      ),
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          row([key('1'), key('2'), key('3')]),
          row([key('4'), key('5'), key('6')]),
          row([key('7'), key('8'), key('9')]),
          row([
            const SizedBox.shrink(),
            key('0'),
            _Key(
              onPressed: enabled ? onDelete : null,
              flat: true,
              tooltip: l10n.pinDelete,
              child: const Icon(Icons.backspace_outlined, size: 26),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.onPressed, required this.child, this.flat = false, this.tooltip});

  final VoidCallback? onPressed;
  final Widget child;
  final bool flat;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        foregroundColor: AppColors.text,
        disabledForegroundColor: AppColors.mutedText.withValues(alpha: 0.5),
        backgroundColor: flat ? Colors.transparent : (onPressed == null ? const Color(0xFFE6ECEB) : AppColors.surface),
        elevation: 0,
        textStyle: const TextStyle(fontFamily: 'sans-serif'),
      ),
      child: child,
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// Collects six digits with [PinDots] and [PinKeypad], and calls [onComplete]
/// with the PIN once the sixth digit is typed. [controller] lets the screen
/// clear it (after a wrong PIN or a mismatch).
class PinEntry extends StatefulWidget {
  const PinEntry({super.key, required this.onComplete, this.controller, this.enabled = true});

  final ValueChanged<String> onComplete;
  final PinEntryController? controller;
  final bool enabled;

  @override
  State<PinEntry> createState() => _PinEntryState();
}

class PinEntryController extends ChangeNotifier {
  void clear() => notifyListeners();
}

class _PinEntryState extends State<PinEntry> {
  String _digits = '';

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_clear);
  }

  @override
  void didUpdateWidget(PinEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_clear);
      widget.controller?.addListener(_clear);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_clear);
    super.dispose();
  }

  void _clear() => setState(() => _digits = '');

  void _add(String digit) {
    if (_digits.length >= 6) return;
    setState(() => _digits += digit);
    if (_digits.length == 6) widget.onComplete(_digits);
  }

  void _delete() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PinDots(filled: _digits.length),
        const SizedBox(height: 20),
        PinKeypad(onDigit: _add, onDelete: _delete, enabled: widget.enabled),
      ],
    );
  }
}
