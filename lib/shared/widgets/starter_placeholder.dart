import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';

class StarterPlaceholder extends StatelessWidget {
  const StarterPlaceholder({
    super.key,
    required this.title,
    required this.owner,
    this.detail,
    this.action,
  });

  final String title;
  final String owner;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => WayhunterUnavailableView(
    title: title,
    message: 'Starter placeholder \u2014 $owner will implement this module.',
    action: detail == null && action == null
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (detail case final message?)
                Text(message, textAlign: TextAlign.center),
              ?action,
            ],
          ),
  );
}
