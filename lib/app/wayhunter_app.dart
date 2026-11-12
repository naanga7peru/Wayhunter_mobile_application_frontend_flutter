import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/wayhunter_module.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_theme.dart';
import 'package:wayhunter_mobile/features/home/presentation/views/home_screen.dart';
import 'package:wayhunter_mobile/shared/widgets/starter_placeholder.dart';

class WayhunterApp extends StatelessWidget {
  const WayhunterApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Wayhunter Starter',
        theme: WayhunterTheme.dark,
        debugShowCheckedModeBanner: false,
        home: const WayhunterShell(),
      );
}

class WayhunterShell extends StatefulWidget {
  const WayhunterShell({super.key});

  @override
  State<WayhunterShell> createState() => _WayhunterShellState();
}

class _WayhunterShellState extends State<WayhunterShell> {
  WayhunterModule? selectedModule;
  int currentTab = 0;

  void selectModule(WayhunterModule module) {
    setState(() {
      selectedModule = module;
      currentTab = 1;
    });
  }

  void selectTab(int tab) {
    setState(() {
      // Before a module is selected, tab 2 falls back to module selection.
      currentTab = tab == 1 && selectedModule == null ? 0 : tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final module = selectedModule;
    final Widget screen = switch (currentTab) {
      0 => HomeScreen(onSelectModule: selectModule),
      1 => StarterPlaceholder(
          title: module?.title ?? 'Choose a module',
          owner: module?.owner ?? 'M2 / M4 / M5',
        ),
      2 => StarterPlaceholder(
          title: '${module?.title ?? 'Module'} leaderboard',
          owner: 'M5 shared UI; ranking source depends on selected module',
        ),
      _ => const StarterPlaceholder(title: 'Profile & Wallet', owner: 'M1 + M6'),
    };

    return Scaffold(
      body: screen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: selectTab,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            label: module?.title ?? 'Modules',
          ),
          const NavigationDestination(icon: Icon(Icons.emoji_events_outlined),
              label: 'Leaderboard'),
          const NavigationDestination(icon: Icon(Icons.person_outline),
              label: 'Profile'),
        ],
      ),
    );
  }
}
