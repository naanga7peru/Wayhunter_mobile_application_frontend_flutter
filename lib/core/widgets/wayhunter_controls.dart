import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/l10n/wayhunter_strings.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';

class WayhunterButton extends StatelessWidget {
  const WayhunterButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
  }) : _primary = true;

  const WayhunterButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
  }) : _primary = false;

  final String label;
  final VoidCallback? onPressed;
  final bool _primary;

  @override
  Widget build(BuildContext context) => _primary
      ? FilledButton(onPressed: onPressed, child: Text(label))
      : OutlinedButton(onPressed: onPressed, child: Text(label));
}

class WayhunterTextField extends StatelessWidget {
  const WayhunterTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        validator: validator,
        onChanged: onChanged,
        keyboardType: keyboardType,
        obscureText: obscureText,
        enabled: enabled,
        decoration: InputDecoration(labelText: label, hintText: hint),
      );
}

Future<bool> showWayhunterConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final strings = WayhunterStrings.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          scrollable: true,
          actions: [
            WayhunterButton.secondary(
              label: strings.cancel,
              onPressed: () => Navigator.pop(context, false),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: WayhunterColors.dangerInk)
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel ?? strings.confirm),
            ),
          ],
        ),
      ) ??
      false;
}
