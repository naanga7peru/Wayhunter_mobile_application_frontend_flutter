import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';

class Person2Content extends StatelessWidget {
  const Person2Content({
    super.key,
    required this.children,
    this.spacing = WayhunterLayout.large,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.symmetric(
          horizontal: constraints.maxWidth < 360
              ? WayhunterLayout.large
              : WayhunterLayout.pagePadding,
          vertical: WayhunterLayout.pagePadding,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: WayhunterLayout.contentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

bool validatePerson2Draft(FormState form) {
  final invalidFields = form.validateGranularly();
  if (invalidFields.isEmpty) return true;

  final firstInvalid = invalidFields.first;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!firstInvalid.mounted) return;
    Scrollable.ensureVisible(
      firstInvalid.context,
      alignment: 0.1,
      duration: const Duration(milliseconds: 180),
    );
  });
  return false;
}

class Person2DraftField extends StatelessWidget {
  const Person2DraftField({
    super.key,
    required this.label,
    required this.hint,
    required this.validator,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
  });

  final String label;
  final String hint;
  final FormFieldValidator<String> validator;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    onChanged: onChanged,
    validator: validator,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    textCapitalization: keyboardType == TextInputType.number
        ? TextCapitalization.none
        : TextCapitalization.sentences,
    minLines: maxLines == 1 ? 1 : 2,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      hintMaxLines: 2,
      errorMaxLines: 4,
      alignLabelWithHint: maxLines > 1,
    ),
  );
}
