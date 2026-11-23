import 'package:flutter/foundation.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/router/route_registration.dart';
import 'package:wayhunter_mobile/app/wayhunter_module.dart'
    show WayhunterModuleInfo;
import 'package:wayhunter_mobile/features/hunter/data/hunter_history_sources.dart';
import 'package:wayhunter_mobile/features/hunter/presentation/hunter_screens.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';
import 'package:wayhunter_mobile/shared/widgets/starter_placeholder.dart';

final person2Routes = <String, RouteRegistration<Object?>>{
  AppRoutes.hunter: RouteRegistration<Null>((_, _) => const HunterHomeScreen()),
  hunterAddNewPlaceRoute: RouteRegistration<Null>(
    (_, _) => const AddNewPlaceScreen(),
  ),
  AppRoutes.games: RouteRegistration<Null>(
    (_, arguments) => const StarterPlaceholder(title: 'Game', owner: 'M5'),
  ),
  AppRoutes.leaderboard: RouteRegistration<ModuleId>(
    (_, module) =>
        StarterPlaceholder(title: '${module.title} leaderboard', owner: 'M5'),
  ),
  AppRoutes.wallet: RouteRegistration<Null>(
    (_, arguments) => const StarterPlaceholder(title: 'Wallet', owner: 'M6'),
  ),
  AppRoutes.myHunts: RouteRegistration<Null>(
    (_, _) => const MyHuntsScreen(
      history: UnavailableHunterHistory(),
      demoHistory: kDebugMode ? DemoHunterHistory() : null,
    ),
  ),
  AppRoutes.myGames: RouteRegistration<Null>(
    (_, arguments) => const StarterPlaceholder(title: 'My Games', owner: 'M5'),
  ),
};
