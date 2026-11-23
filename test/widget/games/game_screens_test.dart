import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/auth/presentation/views/sign_in_screen.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_navigation.dart';
import 'package:wayhunter_mobile/features/games/presentation/my_games.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

void main() {
  testWidgets('Game draft validates, reorders hints and returns for edits', (
    tester,
  ) async {
    await _openGameZone(tester);
    await _tap(tester, 'Create Game');
    await _tap(tester, 'Stages and Hints');
    expect(find.text('Enter a game title.'), findsOneWidget);
    expect(find.text('Enter a description.'), findsOneWidget);
    expect(find.text('Enter a district.'), findsOneWidget);
    expect(
      find.text('Enter a positive whole number of minutes.'),
      findsOneWidget,
    );

    await _enter(tester, 'Game title', '  Coastal trail  ');
    await _enter(tester, 'Description', 'Follow the shoreline.');
    await _enter(tester, 'District', '   ');
    await _enter(tester, 'Play duration (minutes)', '-4');
    await _tap(tester, 'Stages and Hints');
    expect(find.text('Enter a district.'), findsOneWidget);
    expect(
      find.text('Enter a positive whole number of minutes.'),
      findsOneWidget,
    );
    await _enter(tester, 'District', 'Galle');
    await _enter(tester, 'Play duration (minutes)', '30');
    await _tap(tester, 'Stages and Hints');
    await _tap(tester, 'Review Game');
    expect(find.text('Enter a hint for this stage.'), findsOneWidget);

    await _enter(tester, 'Stage 1 hint', '  Look by the pier.  ');
    await _tap(tester, 'Add stage');
    await _enter(tester, 'Stage 2 hint', 'Find the lighthouse.');
    await _tap(tester, 'Add stage');
    await _tapFinder(tester, find.byTooltip('Remove stage 3'));
    expect(find.text('Stage 3 hint'), findsNothing);
    await _tapFinder(tester, find.byTooltip('Move stage 2 up'));
    await _tap(tester, 'Review Game');

    expect(find.text('Coastal trail'), findsOneWidget);
    expect(find.text('District: Galle'), findsOneWidget);
    expect(find.text('Play duration: 30 minutes'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Find the lighthouse.')).dy,
      lessThan(tester.getTopLeft(find.text('Look by the pier.')).dy),
    );
    expect(
      tester
          .widget<WayhunterButton>(
            find.widgetWithText(WayhunterButton, 'Submit for Admin review'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Pending'), findsNothing);

    await _tap(tester, 'Edit stages and hints');
    expect(find.text('Find the lighthouse.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('  Coastal trail  '), findsOneWidget);
    await _enter(tester, 'District', 'Matara');
    await _tap(tester, 'Stages and Hints');
    expect(find.text('Find the lighthouse.'), findsOneWidget);
    await _tap(tester, 'Review Game');
    expect(find.text('District: Matara'), findsOneWidget);
  });

  testWidgets('Play Game and My Games open separately from Game Zone', (
    tester,
  ) async {
    await _openGameZone(tester);
    await _tap(tester, 'Play Game');
    expect(find.text('Live discovery unavailable'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tap(tester, 'My Games');
    expect(find.text('Game history unavailable'), findsOneWidget);
    expect(find.text('Approved'), findsNothing);

    await _tap(tester, 'View development demo');
    expect(find.text('Development demo data'), findsOneWidget);
    for (final status in ['Pending', 'Approved', 'Rejected', 'Archived']) {
      expect(find.text(status), findsOneWidget);
    }
    expect(find.text('Development example'), findsNWidgets(4));
    expect(find.textContaining('Sample reason:'), findsOneWidget);

    await _tap(tester, 'Return to My Games');
    expect(find.text('Game history unavailable'), findsOneWidget);
    expect(find.text('Development demo data'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Game Zone'), findsOneWidget);
  });

  testWidgets('My Games loads, handles read errors and retries to empty', (
    tester,
  ) async {
    final firstRead = Completer<List<CreatedGameSummary>>();
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyGamesScreen(
            loadHistory: () async => ++reads == 1 ? firstRead.future : [],
          ),
        ),
      ),
    );
    expect(find.byType(WayhunterLoadingView), findsOneWidget);
    firstRead.completeError(StateError('Private diagnostic'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load games'), findsOneWidget);
    expect(find.text('Private diagnostic'), findsNothing);

    await _tap(tester, 'Retry');
    expect(reads, 2);
    expect(find.text('No games yet'), findsOneWidget);
    expect(find.text('View development demo'), findsNothing);
  });

  testWidgets(
    'Discovery loads server games, opens details and keeps demo isolated',
    (tester) async {
      final pending = Completer<TransportResponse>();
      final now = DateTime.now().toUtc();
      final game = {
        'gameId': _gameId,
        'title': 'Live trail',
        'description': 'A server description.',
        'durationMinutes': 30,
        'publishedAtUtc': now.toIso8601String(),
        'expiresAtUtc': now.add(const Duration(days: 30)).toIso8601String(),
      };
      final transport = _GamesTransport()
        ..respond = (request) async => request.uri.path.endsWith(_gameId)
            ? _response({...game, 'stageCount': 3})
            : pending.future;
      await _openAuthenticatedGameZone(tester, transport);
      await tester.tap(find.text('Play Game'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(WayhunterLoadingView), findsOneWidget);
      pending.complete(_response([game]));
      await tester.pumpAndSettle();
      expect(find.text('Live trail'), findsOneWidget);
      expect(find.text('Coastal Clues'), findsNothing);

      await _tap(tester, 'Live trail');
      expect(find.text('Stages: 3'), findsOneWidget);
      expect(
        tester
            .widget<WayhunterButton>(
              find.widgetWithText(WayhunterButton, 'Accept Game'),
            )
            .onPressed,
        isNull,
      );
      expect(
        transport.gameRequests.last.uri.path,
        '/api/mobile/games/$_gameId',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'Browse DEMO games');
      expect(find.text('Coastal Clues'), findsOneWidget);
      expect(find.text('Live trail'), findsNothing);
      expect(transport.gameRequests, hasLength(2));
      await _signOut(tester, transport);
      expect(find.text('Live trail'), findsNothing);
    },
  );

  testWidgets(
    'Discovery retries unavailable and failed reads before showing empty',
    (tester) async {
      final results = [
        _response(null, 503),
        _response(null, 409),
        _response([]),
      ];
      final transport = _GamesTransport()
        ..respond = (_) async => results.removeAt(0);
      await _openAuthenticatedGameZone(tester, transport);
      await _tap(tester, 'Play Game');
      expect(find.text('Games service unavailable'), findsOneWidget);
      await _tap(tester, 'Retry');
      expect(find.text('Could not load Games data'), findsOneWidget);
      await _tap(tester, 'Retry');
      expect(find.text('No available games'), findsOneWidget);
      expect(find.text('Coastal Clues'), findsNothing);
      expect(transport.gameRequests, hasLength(3));
    },
  );

  testWidgets(
    'Player history discards the previous account response and stays separate from My Games',
    (tester) async {
      final previousAccount = Completer<TransportResponse>();
      final transport = _GamesTransport()
        ..respond = (request) async =>
            request.headers['Authorization'] == 'Bearer first'
            ? previousAccount.future
            : _response([_attempt]);
      final session = await _openAuthenticatedGameZone(tester, transport);
      await tester.ensureVisible(find.text('My Game Attempts'));
      await tester.tap(find.text('My Game Attempts'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(WayhunterLoadingView), findsOneWidget);

      await _signOut(tester, transport);
      expect(session.accessToken, isNull);
      expect(find.text('Player history'), findsNothing);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'second@example.invalid');
      await tester.enterText(fields.last, 'SyntheticPassword42');
      await _tapFinder(tester, find.widgetWithText(FilledButton, 'Sign In'));
      expect(session.state.user?.id, 'second');
      expect(find.text('Choose a module'), findsOneWidget);
      expect(find.text('Player history'), findsNothing);
      expect(_navigator(tester).canPop(), isFalse);
      await _selectGameModule(tester);
      await _tap(tester, 'My Game Attempts');
      await tester.pumpAndSettle();
      expect(find.text('Player history'), findsOneWidget);
      expect(find.text('Waiting for verification'), findsOneWidget);
      expect(find.text('Attempt ID: $_attemptId'), findsOneWidget);
      expect(find.text('Resume'), findsNothing);
      previousAccount.complete(
        _response([
          {..._attempt, 'status': 4},
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rejected'), findsNothing);
      expect(
        transport.gameRequests.map((r) => r.uri.path),
        everyElement('/api/mobile/games/me/attempts'),
      );
      expect(transport.gameRequests.map((r) => r.headers['Authorization']), [
        'Bearer first',
        'Bearer second',
      ]);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'My Games');
      expect(find.text('Game history unavailable'), findsOneWidget);
      expect(find.text('Player history'), findsNothing);
      expect(find.text('Attempt ID: $_attemptId'), findsNothing);
      expect(transport.gameRequests, hasLength(2));
    },
  );

  testWidgets('Game routes reject unexpected arguments', (tester) async {
    await tester.pumpWidget(const WayhunterApp());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    for (final route in [
      AppRoutes.games,
      createGameRoute,
      playGameRoute,
      gameDetailsRoute,
      myGameAttemptsRoute,
      AppRoutes.myGames,
    ]) {
      navigator.pushNamed<void>(route, arguments: 'unexpected');
      await tester.pumpAndSettle();
      expect(find.text('This destination is unavailable.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}

Future<void> _openGameZone(WidgetTester tester) async {
  await tester.pumpWidget(const WayhunterApp());
  await _selectGameModule(tester);
}

Future<void> _selectGameModule(WidgetTester tester) async {
  await _tapFinder(tester, find.text('Game').first);
  expect(find.text('Game Zone'), findsOneWidget);
}

NavigatorState _navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator));

Future<void> _signOut(WidgetTester tester, _GamesTransport transport) async {
  final protectedNavigator = _navigator(tester);
  unawaited(protectedNavigator.pushNamed<void>(AppRoutes.profile));
  await tester.pumpAndSettle();
  await _tap(tester, 'Sign out');
  expect(transport.logoutRequests, 1);
  expect(protectedNavigator.mounted, isFalse);
  expect(find.byType(SignInScreen), findsOneWidget);
  expect(_navigator(tester).canPop(), isFalse);
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(find.byType(SignInScreen), findsOneWidget);
}

Future<void> _tap(WidgetTester tester, String label) =>
    _tapFinder(tester, find.text(label));

Future<void> _tapFinder(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

const _gameId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const _attemptId = '11111111-2222-3333-4444-555555555555';
const _timestamp = '2026-11-23T08:00:00Z';
const _attempt = {
  'attemptId': _attemptId,
  'gameId': _gameId,
  'startedAtUtc': _timestamp,
  'deadlineUtc': null,
  'status': 2,
  'currentStepNumber': 1,
  'totalSteps': 3,
};

Future<SessionController> _openAuthenticatedGameZone(
  WidgetTester tester,
  _GamesTransport transport,
) async {
  final session = SessionController(_TestStore());
  addTearDown(session.dispose);
  await tester.pumpWidget(
    FoundationServices(
      session: session,
      api: ApiClient(
        baseUrl: Uri.parse('https://wayhunter.test'),
        tokens: session,
        transport: transport,
      ),
      child: const WayhunterApp.authenticated(apiConfigured: true),
    ),
  );
  await tester.pumpAndSettle();
  expect(session.state.user?.id, 'first');
  expect(transport.gameRequests, isEmpty);
  await _selectGameModule(tester);
  return session;
}

TransportResponse _response(Object? data, [int status = 200]) =>
    TransportResponse(status, utf8.encode(jsonEncode(data)));

class _GamesTransport implements HttpTransport {
  final gameRequests = <TransportRequest>[];
  int logoutRequests = 0;
  late Future<TransportResponse> Function(TransportRequest) respond;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    final bearer = request.headers['Authorization'];
    switch ((request.method, request.uri.path)) {
      case (ApiMethod.get, '/api/mobile/identity/me'):
        expect(bearer, anyOf('Bearer first', 'Bearer second'));
        return _response({
          'userId': bearer == 'Bearer first' ? 'first' : 'second',
          'displayName': 'Synthetic visitor',
          'email': 'visitor@example.invalid',
        });
      case (ApiMethod.get, '/api/mobile/advertisements/active'):
        return _response([]);
      case (ApiMethod.post, '/api/mobile/auth/logout'):
        expect(bearer, 'Bearer first');
        logoutRequests++;
        return const TransportResponse(204, []);
      case (ApiMethod.post, '/api/mobile/identity/login'):
        expect(jsonDecode(request.body!)['email'], 'second@example.invalid');
        return _response({
          'userId': 'second',
          'accessToken': 'second',
          'expiresAtUtc': '2099-01-01T00:00:00Z',
        });
      case (ApiMethod.get, final path)
          when path == '/api/mobile/games' ||
              path.startsWith('/api/mobile/games/'):
        expect(bearer, anyOf('Bearer first', 'Bearer second'));
        gameRequests.add(request);
        return respond(request);
      default:
        fail('Unexpected request: ${request.method} ${request.uri.path}');
    }
  }
}

class _TestStore implements CredentialStore {
  SessionCredential? _value = const SessionCredential(
    user: UserRef('first'),
    accessToken: 'first',
  );

  @override
  Future<void> clear() async => _value = null;

  @override
  Future<SessionCredential?> read() async => _value;

  @override
  Future<void> write(SessionCredential credential) async => _value = credential;
}
