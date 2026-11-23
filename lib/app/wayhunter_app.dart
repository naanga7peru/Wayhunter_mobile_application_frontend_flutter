import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/navigation/wayhunter_shell.dart';
import 'package:wayhunter_mobile/app/router/app_router.dart';
import 'package:wayhunter_mobile/app/router/person1_routes.dart';
import 'package:wayhunter_mobile/app/wayhunter_module.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_theme.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/auth/data/identity_api.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_gate.dart';

class WayhunterApp extends StatelessWidget {
  /// Legacy standalone shell harness used by navigation and feature tests.
  /// The application entry point always uses [WayhunterApp.authenticated].
  const WayhunterApp({super.key, this.environmentLabel = 'development'})
    : _apiConfigured = null;

  const WayhunterApp.authenticated({
    super.key,
    this.environmentLabel = 'development',
    required bool apiConfigured,
  }) : _apiConfigured = apiConfigured;

  final String environmentLabel;
  final bool? _apiConfigured;

  Widget _authPage(Widget body) {
    final home = WayhunterPageScaffold(body: body);
    return _StartupHome(
      home: home,
      child: MaterialApp(
        title: 'Wayhunter ($environmentLabel)',
        theme: WayhunterTheme.light,
        debugShowCheckedModeBanner: false,
        onGenerateInitialRoutes: _StartupHome.rootRoutes,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => WayhunterPageScaffold(
            appBar: AppBar(),
            body: const WayhunterUnavailableView(
              title: 'Sign in to access this page',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configured = _apiConfigured;
    if (configured == null &&
        !kReleaseMode &&
        context.dependOnInheritedWidgetOfExactType<FoundationServices>() ==
            null) {
      return _ShellApp(environmentLabel: environmentLabel);
    }
    if (configured != true) {
      return _authPage(
        const WayhunterUnavailableView(
          title: 'Authentication is unavailable',
          message: 'This build requires a configured HTTPS API origin.',
        ),
      );
    }
    final services = FoundationServices.of(context);
    return AuthGate(
      key: ObjectKey(services.session),
      api: IdentityApi(services.api),
      session: services.session,
      authPage: _authPage,
      protectedApp: (_) =>
          _ShellApp(environmentLabel: environmentLabel, authenticated: true),
    );
  }
}

class _ShellApp extends StatefulWidget {
  const _ShellApp({required this.environmentLabel, this.authenticated = false});

  final String environmentLabel;
  final bool authenticated;

  @override
  State<_ShellApp> createState() => _ShellAppState();
}

class _ShellAppState extends State<_ShellApp> {
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
  Widget build(BuildContext context) {
    final home = Builder(
      builder: (_) => WayhunterShell(
        router: _router,
        module: _module,
        tab: _tab,
        onSelectTab: _selectTab,
      ),
    );
    final app = MaterialApp(
      title: 'Wayhunter Starter (${widget.environmentLabel})',
      theme: WayhunterTheme.light,
      debugShowCheckedModeBanner: false,
      onGenerateInitialRoutes: widget.authenticated
          ? _StartupHome.rootRoutes
          : null,
      onGenerateRoute: (settings) {
        if (widget.authenticated && settings.name == person1AuthRoute) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                const WayhunterPageScaffold(body: AppRouter.unavailable),
          );
        }
        return _router.onGenerateRoute(settings);
      },
      home: widget.authenticated ? null : home,
    );
    return widget.authenticated ? _StartupHome(home: home, child: app) : app;
  }
}

/// A platform launch route cannot populate either authentication stack.
class _StartupHome extends InheritedWidget {
  const _StartupHome({required this.home, required super.child});

  final Widget home;

  static List<Route<dynamic>> rootRoutes(String _) => [
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: Navigator.defaultRouteName),
      builder: (context) =>
          context.dependOnInheritedWidgetOfExactType<_StartupHome>()!.home,
    ),
  ];

  @override
  bool updateShouldNotify(_StartupHome oldWidget) => home != oldWidget.home;
}
