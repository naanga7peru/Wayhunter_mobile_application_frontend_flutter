import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/router/person1_routes.dart';
import 'package:wayhunter_mobile/app/router/person2_routes.dart';
import 'package:wayhunter_mobile/app/router/route_registration.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

class AppRouter {
  AppRouter(ValueChanged<ModuleId> selectModule)
      : _routes = _compose(person1Routes(selectModule), person2Routes);

  final Map<String, RouteRegistration<Object?>> _routes;

  static Map<String, RouteRegistration<Object?>> _compose(
    Map<String, RouteRegistration<Object?>> first,
    Map<String, RouteRegistration<Object?>> second,
  ) =>
      {
        ...first,
        ...second,
        // A duplicate route is unavailable until its ownership is resolved.
        for (final name in first.keys.where(second.containsKey))
          name: RouteRegistration<Null>((_, arguments) => unavailable),
      };

  static const unavailable = WayhunterUnavailableView();

  Widget destination(BuildContext context, String name, [Object? arguments]) =>
      _routes[name]?.build(context, arguments) ?? unavailable;

  Route<void> onGenerateRoute(RouteSettings settings) =>
      MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => WayhunterPageScaffold(
          appBar: AppBar(),
          body: destination(context, settings.name ?? '', settings.arguments),
        ),
      );
}
