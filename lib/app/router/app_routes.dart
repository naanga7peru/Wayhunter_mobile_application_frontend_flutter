import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

abstract final class AppRoutes {
  static const home = 'home';
  static const traveller = 'traveller.home';
  static const hunter = 'hunter.home';
  static const games = 'games.home';
  static const leaderboard = 'leaderboard.module';
  static const profile = 'profile.me';
  static const userProfile = 'profile.user';
  static const addPlace = 'traveller.addPlace';
  static const tripPlan = 'traveller.plan';
  static const activeTrip = 'traveller.activeTrip';
  static const wallet = 'wallet.home';
  static const myHunts = 'hunter.myHunts';
  static const myGames = 'games.myGames';

  static String moduleHome(ModuleId module) => switch (module) {
        ModuleId.traveler => traveller,
        ModuleId.hunter => hunter,
        ModuleId.game => games,
      };
}

class ActiveTripArgs {
  const ActiveTripArgs({required this.plan, required this.session});

  final TripPlanRef plan;
  final TripSessionRef session;
}

class AppDestination {
  const AppDestination(this.name) : arguments = null;
  const AppDestination.leaderboard(ModuleId module)
      : name = AppRoutes.leaderboard,
        arguments = module;
  const AppDestination.userProfile(UserRef user)
      : name = AppRoutes.userProfile,
        arguments = user;
  const AppDestination.addPlace(PlaceRef place)
      : name = AppRoutes.addPlace,
        arguments = place;
  const AppDestination.tripPlan(TripPlanRef plan)
      : name = AppRoutes.tripPlan,
        arguments = plan;
  const AppDestination.activeTrip(ActiveTripArgs trip)
      : name = AppRoutes.activeTrip,
        arguments = trip;

  final String name;
  final Object? arguments;

  Future<void> open(BuildContext context) =>
      Navigator.of(context).pushNamed<void>(name, arguments: arguments);
}
