import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';

class WayhunterPageScaffold extends StatelessWidget {
  const WayhunterPageScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar,
        bottomNavigationBar: bottomNavigationBar,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: WayhunterLayout.gradient),
          child: SizedBox.expand(child: body),
        ),
      );
}

class WayhunterHeader extends StatelessWidget {
  const WayhunterHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineMedium),
        ),
        if (subtitle case final text?) ...[
          const SizedBox(height: WayhunterLayout.small),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}
