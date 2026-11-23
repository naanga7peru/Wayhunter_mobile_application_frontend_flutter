import 'package:flutter/foundation.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/router/route_registration.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_creation.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_navigation.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_playing.dart';
import 'package:wayhunter_mobile/features/games/presentation/my_games.dart';
import 'package:wayhunter_mobile/features/hunter/data/hunter_history_sources.dart';
import 'package:wayhunter_mobile/features/hunter/presentation/hunter_screens.dart';
import 'package:wayhunter_mobile/features/leaderboards/presentation/leaderboard_screens.dart';
import 'package:wayhunter_mobile/features/wallet/presentation/wallet_screens.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

final person2Routes = <String, RouteRegistration<Object?>>{
  AppRoutes.hunter: RouteRegistration<Null>((_, _) => const HunterHomeScreen()),
  hunterAddNewPlaceRoute: RouteRegistration<Null>(
    (_, _) => const AddNewPlaceScreen(),
  ),
  AppRoutes.games: RouteRegistration<Null>((_, _) => const GameZoneScreen()),
  createGameRoute: RouteRegistration<Null>((_, _) => const CreateGameScreen()),
  playGameRoute: RouteRegistration<Null>(
    (_, _) => const PlayGameScreen(enableDemo: kDebugMode),
  ),
  AppRoutes.leaderboard: RouteRegistration<ModuleId>(
    (_, module) =>
        LeaderboardHomeScreen(key: ValueKey(module), initialModule: module),
  ),
  AppRoutes.wallet: RouteRegistration<Null>(
    (_, _) => const WalletHomeScreen(embedded: true),
  ),
  AppRoutes.myHunts: RouteRegistration<Null>(
    (_, _) => const MyHuntsScreen(
      history: UnavailableHunterHistory(),
      demoHistory: kDebugMode ? DemoHunterHistory() : null,
    ),
  ),
  AppRoutes.myGames: RouteRegistration<Null>(
    (_, _) => const MyGamesScreen(enableDemo: kDebugMode),
  ),
};
