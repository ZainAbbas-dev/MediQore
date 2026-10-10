import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Free-text field, for example a name.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.ltr = false,
    this.maxLength,
  });

  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  /// Hides the text, for passwords.
  final bool obscureText;

  /// Left to right even in the Urdu layout, for IDs, passwords and codes.
  final bool ltr;

  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        TextFormField(
          controller: controller,
          validator: validator,
          onChanged: onChanged,
          keyboardType: keyboardType,
          obscureText: obscureText,
          textDirection: ltr ? TextDirection.ltr : null,
          maxLength: maxLength,
          autocorrect: !ltr,
          enableSuggestions: !ltr && !obscureText,
          style: const TextStyle(fontSize: 18),
        ),
      ],
    );
  }
}

/// Numeric entry for a vital sign. The number and its unit always read left to
/// right, even inside the right-to-left Urdu layout (roadmap: Urdu text rule).
/// Only digits (and a decimal point with up to [decimals] digits after it) can
/// be typed.
class VitalField extends StatelessWidget {
  const VitalField({
    super.key,
    required this.label,
    required this.unit,
    this.controller,
    this.validator,
    this.onChanged,
    this.decimals = 0,
  });

  final String label;

  /// Stored unit of the vital, for example mmHg (CLAUDE.md: one unit per vital).
  final String unit;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  /// Digits allowed after the decimal point; 0 for whole numbers.
  final int decimals;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextFormField(
            controller: controller,
            validator: validator,
            onChanged: onChanged,
            keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
            textInputAction: TextInputAction.next, // the keyboard moves on to the next vital
            inputFormatters: [_KeepIfMatches(decimals > 0 ? RegExp('^\\d*\\.?\\d{0,$decimals}\$') : RegExp(r'^\d*$'))],
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 20),
            // The unit shows while the field is still empty (a suffix would
            // appear only once the field has focus).
            decoration: InputDecoration(
              suffixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  unit,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(),
            ),
          ),
        ),
      ],
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
  const NumberField({super.key, required this.label, this.controller, this.validator, this.maxDigits = 2});

  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final int maxDigits;

  @override
  Widget build(BuildContext context) {
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
            style: const TextStyle(fontSize: 20),
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
