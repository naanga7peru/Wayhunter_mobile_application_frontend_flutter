import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/router/route_registration.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/session_api.dart';
import 'package:wayhunter_mobile/features/games/data/api_games_reader.dart';
import 'package:wayhunter_mobile/features/games/domain/games_reader.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_creation.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_read_screens.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_navigation.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_playing.dart';
import 'package:wayhunter_mobile/features/games/presentation/my_games.dart';
import 'package:wayhunter_mobile/features/hunter/data/hunter_history_sources.dart';
import 'package:wayhunter_mobile/features/hunter/data/api_hunter_reader.dart';
import 'package:wayhunter_mobile/features/hunter/presentation/hunter_screens.dart';
import 'package:wayhunter_mobile/features/leaderboards/presentation/leaderboard_screens.dart';
import 'package:wayhunter_mobile/features/wallet/data/repositories/api_wallet_reader.dart';
import 'package:wayhunter_mobile/features/wallet/data/repositories/api_voucher_redemption_repository.dart';
import 'package:wayhunter_mobile/features/wallet/presentation/wallet_screens.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

final person2Routes = <String, RouteRegistration<Object?>>{
  AppRoutes.hunter: RouteRegistration<Null>(
    (context, _) => _withSession(
      context,
      (key, api) => HunterHomeScreen(
        key: key,
        loadPlaces: api == null ? null : ApiHunterReader(api).readPlaces,
      ),
    ),
  ),
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
  AppRoutes.wallet: RouteRegistration<Null>(
    (context, _) => _withSession(context, (key, api) {
      final services = context
          .getInheritedWidgetOfExactType<FoundationServices>();
      return WalletHomeScreen(
        key: key,
        embedded: true,
        reader: api == null ? null : ApiWalletReader(api),
        redemption: api == null || services == null
            ? null
            : ApiVoucherRedemptionRepository(services.api, services.session),
      );
    }),
  ),
  AppRoutes.myHunts: RouteRegistration<Null>(
    (context, _) => _withSession(context, (key, api) {
      final reader = api == null ? null : ApiHunterReader(api);
      return MyHuntsScreen(
        key: key,
        history: reader ?? const UnavailableHunterHistory(),
        demoHistory: kDebugMode ? const DemoHunterHistory() : null,
        readStatus: reader?.readStatus,
      );
    }),
  ),
  AppRoutes.myGames: RouteRegistration<Null>(
    (context, _) => _withGamesSession(
      context,
      (key, reader) => MyGamesScreen(
        key: key,
        loadHistory: reader?.readMyGames,
        enableDemo: kDebugMode,
      ),
    ),
  ),
};

Widget _withGamesSession(
  BuildContext context,
  Widget Function(Key?, ApiGamesReader?) build,
) => _withSession(
  context,
  (key, api) => build(key, api == null ? null : ApiGamesReader(api)),
);

Widget _withSession(
  BuildContext context,
  Widget Function(Key?, SessionApi?) build,
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
            ? SessionApi(services.api, services.session)
            : null,
      );
    },
  );
}
