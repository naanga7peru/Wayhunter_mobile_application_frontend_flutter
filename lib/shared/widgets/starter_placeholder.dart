import 'package:flutter/material.dart';

class StarterPlaceholder extends StatelessWidget {
  const StarterPlaceholder({
    super.key,
    required this.title,
    required this.owner,
  });

  final String title;
  final String owner;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 54),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text('Starter placeholder — $owner will implement this module.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('No real authentication, maps, approvals or Coins are active.',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
