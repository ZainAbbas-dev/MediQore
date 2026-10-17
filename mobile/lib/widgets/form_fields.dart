import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Form controls for Urdu data entry (M3 FE-1). Labels sit above the control
/// rather than floating inside it, so tall Nastaliq text is never clipped.
/// The app has no audio guidance (LI-6): it relies on written labels.

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// Free-text field, for example a name. An optional [icon] sits at the start
/// of the field, so the field is recognised at a glance (LI-6).
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.label,
    this.controller,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.ltr = false,
    this.maxLength,
    this.icon,
    this.code = false,
  });

  /// Shown above the field; null when the card's heading already says it.
  final String? label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  /// Hides the text, for passwords; an eye button shows it while needed.
  final bool obscureText;

  /// Left to right even in the Urdu layout, for IDs, passwords and codes.
  final bool ltr;

  /// The most characters the field takes; no counter is shown.
  final int? maxLength;

  final IconData? icon;

  /// A code read from a screen or paper (activation or reply code): large,
  /// bold, spaced letters in the middle of the field.
  final bool code;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) _FieldLabel(widget.label!),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          onChanged: widget.onChanged,
          keyboardType: widget.keyboardType,
          obscureText: _hidden,
          textDirection: widget.ltr ? TextDirection.ltr : null,
          // Latin text in an Urdu screen still lines up on the right, with the labels.
          textAlign: widget.code
              ? TextAlign.center
              : widget.ltr && Directionality.of(context) == TextDirection.rtl
              ? TextAlign.right
              : TextAlign.start,
          maxLength: widget.maxLength,
          buildCounter: _noCounter,
          autocorrect: !widget.ltr,
          enableSuggestions: !widget.ltr && !widget.obscureText,
          textCapitalization: widget.code ? TextCapitalization.characters : TextCapitalization.none,
          style: widget.code
              ? const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 3)
              : const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            prefixIcon: widget.icon == null ? null : Icon(widget.icon, color: muted),
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    tooltip: _hidden ? l10n.fieldShowPassword : l10n.fieldHidePassword,
                    color: muted,
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

Widget? _noCounter(BuildContext context, {required int currentLength, required bool isFocused, required int? maxLength}) =>
    null;

/// Numeric entry for a vital sign. The number and its unit always read left to
/// right, even inside the right-to-left Urdu layout (roadmap: Urdu text rule).
/// Only digits (and a decimal point with up to [decimals] digits after it) can
/// be typed.
///
/// With [card] it is the final design's vital card (screen 15): a white card
/// with the label at the top, the number large inside it, an optional
/// [headerTrailing] beside the label (the blood sugar unit) and [footer] under
/// the number (the pulse counter button). The card's border turns teal while
/// the LHW types in it; [optional] values have a light teal border.
class VitalField extends StatefulWidget {
  const VitalField({
    super.key,
    required this.label,
    required this.unit,
    this.controller,
    this.validator,
    this.onChanged,
    this.decimals = 0,
    this.card = false,
    this.optional = false,
    this.headerTrailing,
    this.footer = const [],
  });

  final String label;

  /// Stored unit of the vital, for example mmHg (CLAUDE.md: one unit per vital).
  final String unit;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  /// Digits allowed after the decimal point; 0 for whole numbers.
  final int decimals;

  final bool card;
  final bool optional;
  final Widget? headerTrailing;
  final List<Widget> footer;

  @override
  State<VitalField> createState() => _VitalFieldState();
}

class _VitalFieldState extends State<VitalField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final decimals = widget.decimals;
    // The unit shows while the field is still empty (a suffix would appear
    // only once the field has focus).
    final unit = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(widget.unit, style: theme.textTheme.titleMedium?.copyWith(color: muted)),
    );
    const none = InputBorder.none;
    final field = Directionality(
      textDirection: TextDirection.ltr,
      child: TextFormField(
        controller: widget.controller,
        validator: widget.validator,
        onChanged: widget.onChanged,
        focusNode: _focus,
        keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
        textInputAction: TextInputAction.next, // the keyboard moves on to the next vital
        inputFormatters: [_KeepIfMatches(decimals > 0 ? RegExp('^\\d*\\.?\\d{0,$decimals}\$') : RegExp(r'^\d*$'))],
        textDirection: TextDirection.ltr,
        style: widget.card ? const TextStyle(fontSize: 28, fontWeight: FontWeight.w800) : const TextStyle(fontSize: 20),
        decoration: widget.card
            ? InputDecoration(
                filled: false,
                isDense: true,
                constraints: const BoxConstraints(),
                contentPadding: const EdgeInsets.only(top: 6, bottom: 2),
                border: none,
                enabledBorder: none,
                focusedBorder: none,
                errorBorder: none,
                focusedErrorBorder: none,
                suffixIcon: unit,
                suffixIconConstraints: const BoxConstraints(),
              )
            : InputDecoration(suffixIcon: unit, suffixIconConstraints: const BoxConstraints()),
      ),
    );
    if (!widget.card) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_FieldLabel(widget.label), field]);
    }
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
        border: Border.all(
          color: focused
              ? AppColors.primary
              : widget.optional
              ? AppColors.primaryLight
              : AppColors.fieldBorder,
          width: focused || widget.optional ? 2 : 1,
        ),
      ),
      child: InkWell(
        // A tap anywhere on the card starts typing in it.
        borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
        onTap: _focus.requestFocus,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The trailing control moves under the label when both do not fit.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    widget.label,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted, fontWeight: FontWeight.w600),
                  ),
                  ?widget.headerTrailing,
                ],
              ),
              field,
              for (final child in widget.footer) ...[const SizedBox(height: 10), child],
            ],
          ),
        ),
      ),
    );
  }
}

/// Refuses a keystroke that would make the text stop matching [pattern]: the
/// text stays as it was (a filter would empty the whole field instead).
class _KeepIfMatches extends TextInputFormatter {
  _KeepIfMatches(this.pattern);

  final RegExp pattern;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      pattern.hasMatch(newValue.text) ? newValue : oldValue;
}

/// A whole number without a unit, for example an age or a count of previous
/// pregnancies. Digits only, always left to right.
class NumberField extends StatelessWidget {
  const NumberField({super.key, required this.label, this.controller, this.validator, this.maxDigits = 2, this.icon});

  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final int maxDigits;

  /// At the start of the field in the screen's direction, like [AppTextField].
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // The number reads left to right; the icon still sits where the screen's
    // other fields have theirs (on the right in Urdu).
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final iconWidget = icon == null ? null : Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(maxDigits)],
            textDirection: TextDirection.ltr,
            textAlign: rtl ? TextAlign.right : TextAlign.left,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(prefixIcon: rtl ? null : iconWidget, suffixIcon: rtl ? iconWidget : null),
          ),
        ),
      ],
    );
  }
}

/// Large checkbox row for yes/no symptoms, for example bleeding.
class CheckboxField extends StatelessWidget {
  const CheckboxField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (checked) {
        onChanged(checked ?? false);
      },
      title: Text(label, style: Theme.of(context).textTheme.titleMedium),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// One option of a [DropdownField].
class DropdownOption<T> {
  const DropdownOption(this.value, this.label);

  final T value;
  final String label;
}

/// Dropdown with the label above it.
class DropdownField<T> extends StatelessWidget {
  const DropdownField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final List<DropdownOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          onChanged: onChanged,
          validator: validator,
          style: Theme.of(context).textTheme.titleMedium,
          items: [for (final option in options) DropdownMenuItem<T>(value: option.value, child: Text(option.label))],
        ),
      ],
    );
  }
}
