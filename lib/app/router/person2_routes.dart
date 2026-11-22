import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/router/route_registration.dart';
import 'package:wayhunter_mobile/app/wayhunter_module.dart'
    show WayhunterModuleInfo;
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';
import 'package:wayhunter_mobile/shared/widgets/starter_placeholder.dart';

final person2Routes = <String, RouteRegistration<Object?>>{
  AppRoutes.hunter: RouteRegistration<Null>(
    (context, _) => StarterPlaceholder(
      title: 'Location Hunter',
      owner: 'M4',
      action: TextButton(
        onPressed: () => const AppDestination.addPlace(
          PlaceRef('demo-hunter-place', source: PlaceSource.hunterApproved),
        ).open(context),
        child: const Text('SAMPLE: Preview adding a Hunter place to Traveler'),
      ),
    ),
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
    (_, arguments) => const StarterPlaceholder(title: 'My Hunts', owner: 'M4'),
  ),
  AppRoutes.myGames: RouteRegistration<Null>(
    (_, arguments) => const StarterPlaceholder(title: 'My Games', owner: 'M5'),
  ),
};
