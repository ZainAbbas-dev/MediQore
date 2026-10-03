import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Form controls for Urdu data entry (M3 FE-1). Labels sit above the control
/// rather than floating inside it, so tall Nastaliq text is never clipped.

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
  });

  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  /// Hides the text, for passwords.
  final bool obscureText;

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
          style: const TextStyle(fontSize: 20),
        ),
      ],
    );
  }
}

/// Numeric entry for a vital sign. The number and its unit always read left to
/// right, even inside the right-to-left Urdu layout (roadmap: Urdu text rule).
/// Only digits (and one decimal point when [allowDecimal]) can be typed.
class VitalField extends StatelessWidget {
  const VitalField({
    super.key,
    required this.label,
    required this.unit,
    this.controller,
    this.validator,
    this.onChanged,
    this.allowDecimal = false,
  });

  final String label;

  /// Stored unit of the vital, for example mmHg (CLAUDE.md: one unit per vital).
  final String unit;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool allowDecimal;

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
            keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
            inputFormatters: [
              FilteringTextInputFormatter.allow(allowDecimal ? RegExp(r'^\d*\.?\d*$') : RegExp(r'^\d*$')),
            ],
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 22),
            decoration: InputDecoration(suffixText: unit),
          ),
        ),
      ],
    );
  }
}

/// Large checkbox row for yes/no symptoms, for example bleeding.
class CheckboxField extends StatelessWidget {
  const CheckboxField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (checked) => onChanged(checked ?? false),
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
  });

  final String label;
  final List<DropdownOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;

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
          style: Theme.of(context).textTheme.titleMedium,
          items: [
            for (final option in options)
              DropdownMenuItem<T>(value: option.value, child: Text(option.label)),
          ],
        ),
      ],
    );
  }
}
