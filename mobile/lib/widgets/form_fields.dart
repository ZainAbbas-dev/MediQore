import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../voice/voice_guide.dart';

/// Form controls for Urdu data entry (M3 FE-1). Labels sit above the control
/// rather than floating inside it, so tall Nastaliq text is never clipped.
///
/// Inside a [VoiceScope], a field reads its label aloud when it gets focus and
/// shows a speaker next to the label while it has focus (M3 FE-3). A checkbox
/// or dropdown reads its label when it is tapped.

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.speaking = false});

  final String text;

  /// Voice guidance is on and this field has focus.
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(text, style: style)),
          if (speaking)
            Icon(
              Icons.volume_up,
              color: Theme.of(context).colorScheme.primary,
              semanticLabel: AppLocalizations.of(context).voiceReadingAloud,
            ),
        ],
      ),
    );
  }
}

/// Reads [label] aloud when a field inside [builder] gets focus (M3 FE-3).
/// [builder] learns whether to show the speaker.
class _Voiced extends StatefulWidget {
  const _Voiced({required this.label, required this.builder});

  final String label;
  final Widget Function(BuildContext context, bool speaking) builder;

  @override
  State<_Voiced> createState() => _VoicedState();
}

class _VoicedState extends State<_Voiced> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final guidance = VoiceScope.maybeOf(context);
    if (guidance == null) return widget.builder(context, false);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        if (focused) guidance.announce(widget.label);
      },
      child: widget.builder(context, guidance.isActive && _focused),
    );
  }
}

void _announce(BuildContext context, String label) => VoiceScope.maybeOf(context)?.announce(label);

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
    return _Voiced(
      label: label,
      builder: (context, speaking) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(label, speaking: speaking),
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
      ),
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
    return _Voiced(
      label: label,
      builder: (context, speaking) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(label, speaking: speaking),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextFormField(
              controller: controller,
              validator: validator,
              onChanged: onChanged,
              keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
              textInputAction: TextInputAction.next, // the keyboard moves on to the next vital
              inputFormatters: [
                _KeepIfMatches(decimals > 0 ? RegExp('^\\d*\\.?\\d{0,$decimals}\$') : RegExp(r'^\d*$')),
              ],
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 20),
              // The unit shows while the field is still empty (a suffix would
              // appear only once the field has focus).
              decoration: InputDecoration(
                suffixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    unit,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
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
  const NumberField({super.key, required this.label, this.controller, this.validator, this.maxDigits = 2});

  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final int maxDigits;

  @override
  Widget build(BuildContext context) {
    return _Voiced(
      label: label,
      builder: (context, speaking) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(label, speaking: speaking),
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
      ),
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
      onChanged: (checked) {
        _announce(context, label);
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
    return _Voiced(
      label: label,
      builder: (context, speaking) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(label, speaking: speaking),
          DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            onChanged: onChanged,
            onTap: () => _announce(context, label),
            validator: validator,
            style: Theme.of(context).textTheme.titleMedium,
            items: [
              for (final option in options)
                DropdownMenuItem<T>(value: option.value, child: Text(option.label)),
            ],
          ),
        ],
      ),
    );
  }
}
