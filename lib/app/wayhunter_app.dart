import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/navigation/wayhunter_shell.dart';
import 'package:wayhunter_mobile/app/router/app_router.dart';
import 'package:wayhunter_mobile/app/wayhunter_module.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_theme.dart';

class WayhunterApp extends StatefulWidget {
  const WayhunterApp({super.key, this.environmentLabel = 'development'});

  final String environmentLabel;

  @override
  State<WayhunterApp> createState() => _WayhunterAppState();
}

class _WayhunterAppState extends State<WayhunterApp> {
  ModuleId? _module;
  int _tab = 0;
  late final AppRouter _router = AppRouter(_selectModule);

  void _selectModule(ModuleId module) => setState(() {
        _module = module;
        _tab = 1;
      });

  void _selectTab(int tab) => setState(() {
        _tab = tab == 1 && _module == null ? 0 : tab;
      });

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Wayhunter Starter (${widget.environmentLabel})',
        theme: WayhunterTheme.light,
        debugShowCheckedModeBanner: false,
        onGenerateRoute: _router.onGenerateRoute,
        home: Builder(
          builder: (_) => WayhunterShell(
            router: _router,
            module: _module,
            tab: _tab,
            onSelectTab: _selectTab,
          ),
        ),
      );
}
