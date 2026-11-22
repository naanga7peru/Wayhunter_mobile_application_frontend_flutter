import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/l10n/wayhunter_strings.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';

class WayhunterLoadingView extends StatelessWidget {
  const WayhunterLoadingView({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => Center(
        child: CircularProgressIndicator(
          semanticsLabel: label ?? WayhunterStrings.of(context).loading,
        ),
      );
}

class WayhunterEmptyView extends StatelessWidget {
  const WayhunterEmptyView({super.key, required this.title, this.message});
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) =>
      _StatePanel(icon: Icons.inbox_outlined, title: title, message: message);
}

class WayhunterErrorView extends StatelessWidget {
  const WayhunterErrorView({
    super.key,
    required this.title,
    required this.onRetry,
    this.message,
  });
  final String title;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _StatePanel(
        icon: Icons.error_outline,
        title: title,
        message: message,
        action: WayhunterButton.primary(
          label: WayhunterStrings.of(context).retry,
          onPressed: onRetry,
        ),
      );
}

class WayhunterUnavailableView extends StatelessWidget {
  const WayhunterUnavailableView(
      {super.key, this.title, this.message, this.action});
  final String? title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => _StatePanel(
        icon: Icons.construction_outlined,
        title: title ?? WayhunterStrings.of(context).unavailable,
        message: message,
        action: action,
      );
}

class _StatePanel extends StatelessWidget {
  const _StatePanel(
      {required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WayhunterLayout.pagePadding),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: WayhunterLayout.contentWidth),
            child: WayhunterSurfaceCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 36, color: WayhunterColors.primary),
                  const SizedBox(height: WayhunterLayout.medium),
                  Text(title,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center),
                  if (message case final text?) ...[
                    const SizedBox(height: WayhunterLayout.small),
                    Text(text, textAlign: TextAlign.center),
                  ],
                  if (action case final widget?) ...[
                    const SizedBox(height: WayhunterLayout.large),
                    widget,
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}
