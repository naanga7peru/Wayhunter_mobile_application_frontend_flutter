import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/router/route_registration.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/features/games/data/api_games_reader.dart';
import 'package:wayhunter_mobile/features/games/domain/games_reader.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_creation.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_read_screens.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_navigation.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_playing.dart';
import 'package:wayhunter_mobile/features/games/presentation/my_games.dart';
import 'package:wayhunter_mobile/features/hunter/data/hunter_history_sources.dart';
import 'package:wayhunter_mobile/features/hunter/presentation/hunter_screens.dart';
import 'package:wayhunter_mobile/features/leaderboards/presentation/leaderboard_screens.dart';
import 'package:wayhunter_mobile/features/wallet/data/repositories/api_wallet_reader.dart';
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
    (context, _) => _withGamesSession(
      context,
      (key, reader) =>
          PlayGameScreen(key: key, reader: reader, enableDemo: kDebugMode),
    ),
  ),
  gameDetailsRoute: RouteRegistration<String>(
    (context, id) => _withGamesSession(
      context,
      (key, reader) => GameDetailsScreen(key: key, reader: reader, id: id),
    ),
    validate: isGameId,
  ),
  myGameAttemptsRoute: RouteRegistration<Null>(
    (context, _) => _withGamesSession(
      context,
      (key, reader) => MyGameAttemptsScreen(key: key, reader: reader),
    ),
  ),
  AppRoutes.leaderboard: RouteRegistration<ModuleId>(
    (_, module) =>
        LeaderboardHomeScreen(key: ValueKey(module), initialModule: module),
  ),
  AppRoutes.wallet: RouteRegistration<Null>((context, _) {
    final services = context
        .dependOnInheritedWidgetOfExactType<FoundationServices>();
    if (services == null) return const WalletHomeScreen(embedded: true);
    final reader = ApiWalletReader(services.api);
    return ListenableBuilder(
      listenable: services.session,
      builder: (context, _) {
        final state = services.session.state;
        return WalletHomeScreen(
          key: ObjectKey(state),
          embedded: true,
          reader: state.status == SessionStatus.authenticated ? reader : null,
        );
      },
    );
  }),
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

Widget _withGamesSession(
  BuildContext context,
  Widget Function(Key?, GamesReader?) build,
) {
  final services = context
      .dependOnInheritedWidgetOfExactType<FoundationServices>();
  if (services == null) return build(null, null);
  return ListenableBuilder(
    listenable: services.session,
    builder: (context, _) {
      final session = services.session.state;
      return build(
        ValueKey((session, services.api)),
        session.status == SessionStatus.authenticated
            ? ApiGamesReader(services.api)
            : null,
      );
    },
  );
}
