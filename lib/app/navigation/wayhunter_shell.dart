import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/router/app_router.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/wayhunter_module.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';

class WayhunterShell extends StatelessWidget {
  const WayhunterShell({
    super.key,
    required this.router,
    required this.module,
    required this.tab,
    required this.onSelectTab,
  });

  final AppRouter router;
  final ModuleId? module;
  final int tab;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final selected = module;
    final body = switch (tab) {
      1 when selected != null =>
        router.destination(context, AppRoutes.moduleHome(selected)),
      2 when selected != null =>
        router.destination(context, AppRoutes.leaderboard, selected),
      2 =>
        const Center(child: Text('Choose a module to view its leaderboard.')),
      3 => router.destination(context, AppRoutes.profile),
      _ => router.destination(context, AppRoutes.home),
    };

    return WayhunterPageScaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: onSelectTab,
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            label: selected?.title ?? 'Modules',
          ),
          const NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Leaderboard',
          ),
          const NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
