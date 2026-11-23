import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/core/auth/access_token_source.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/features/games/data/api_games_reader.dart';
import 'package:wayhunter_mobile/features/games/domain/games_reader.dart';

const gameId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const attemptId = '11111111-2222-3333-4444-555555555555';
const timestamp = '2026-11-23T08:00:00+00:00';
const gameJson = {
  'gameId': gameId,
  'title': 'Server trail',
  'description': null,
  'durationMinutes': 30,
  'publishedAtUtc': timestamp,
  'expiresAtUtc': '2026-12-23T08:00:00Z',
};
const attemptJson = {
  'attemptId': attemptId,
  'gameId': gameId,
  'startedAtUtc': timestamp,
  'deadlineUtc': null,
  'status': 2,
  'currentStepNumber': 1,
  'totalSteps': 3,
};

void main() {
  late _Transport transport;
  late _Tokens tokens;
  late ApiGamesReader reader;

  setUp(() {
    transport = _Transport();
    tokens = _Tokens();
    reader = ApiGamesReader(
      ApiClient(
        baseUrl: Uri.parse('https://wayhunter.test'),
        transport: transport,
        tokens: tokens,
      ),
    );
  });

  test(
    'authenticated GETs map discovery, details and player history',
    () async {
      transport.body = [gameJson];
      final game = (await reader.readGames()).single;
      expect(game, (
        id: gameId,
        title: 'Server trail',
        description: null,
        durationMinutes: 30,
        publishedAt: DateTime.utc(2026, 11, 23, 8),
        expiresAt: DateTime.utc(2026, 12, 23, 8),
      ));

      transport.body = {...gameJson, 'stageCount': 3};
      expect(await reader.readGame(gameId), (game: game, stageCount: 3));

      transport.body = [attemptJson];
      expect((await reader.readMyAttempts()).single, (
        id: attemptId,
        gameId: gameId,
        startedAt: DateTime.utc(2026, 11, 23, 8),
        deadline: null,
        status: GameAttemptStatus.waitingForVerification,
        currentStepNumber: 1,
        totalSteps: 3,
      ));
      expect(transport.requests.map((r) => r.uri.toString()), [
        'https://wayhunter.test/api/mobile/games',
        'https://wayhunter.test/api/mobile/games/$gameId',
        'https://wayhunter.test/api/mobile/games/me/attempts',
      ]);
      for (final request in transport.requests) {
        expect(request.method, ApiMethod.get);
        expect(request.headers['Authorization'], 'Bearer account-one');
        expect(request.body, isNull);
      }
    },
  );

  test('empty arrays and a missing detail are different results', () async {
    transport.body = [];
    expect(await reader.readGames(), isEmpty);
    expect(await reader.readMyAttempts(), isEmpty);
    transport.status = 404;
    expect(await reader.readGame(gameId), isNull);
    await expectLater(reader.readGames(), throwsA(_error(ApiError.notFound)));
  });

  test('missing and malformed responses fail decoding', () async {
    for (final payload in [
      null,
      {},
      [null],
      [
        {...gameJson, 'durationMinutes': '30'},
      ],
    ]) {
      transport.body = payload;
      await expectLater(
        reader.readGames(),
        throwsA(_error(ApiError.invalidResponse)),
      );
    }
    transport.body = {...gameJson, 'gameId': attemptId, 'stageCount': 1};
    await expectLater(
      reader.readGame(gameId),
      throwsA(_error(ApiError.invalidResponse)),
    );
    transport.body = [
      {...attemptJson, 'status': 'Completed'},
    ];
    await expectLater(
      reader.readMyAttempts(),
      throwsA(_error(ApiError.invalidResponse)),
    );
    transport.raw = [123];
    await expectLater(
      reader.readMyAttempts(),
      throwsA(_error(ApiError.invalidResponse)),
    );
  });

  test(
    'shared authentication, network and server failures propagate',
    () async {
      for (final entry in {
        401: ApiError.unauthorized,
        403: ApiError.forbidden,
        409: ApiError.conflict,
        500: ApiError.server,
        503: ApiError.server,
      }.entries) {
        transport.status = entry.key;
        await expectLater(
          reader.readGames(),
          throwsA(
            _error(
              entry.value,
            ).having((e) => e.statusCode, 'statusCode', entry.key),
          ),
        );
      }
      transport.offline = true;
      await expectLater(
        reader.readMyAttempts(),
        throwsA(_error(ApiError.network)),
      );
    },
  );

  test(
    'sign-out blocks transport and the next account uses its own token',
    () async {
      transport.body = [];
      await reader.readMyAttempts();
      tokens.accessToken = null;
      await expectLater(
        reader.readGames(),
        throwsA(_error(ApiError.unauthorized)),
      );
      await expectLater(
        reader.readGame(gameId),
        throwsA(_error(ApiError.unauthorized)),
      );
      await expectLater(
        reader.readMyAttempts(),
        throwsA(_error(ApiError.unauthorized)),
      );
      expect(transport.requests, hasLength(1));
      tokens.accessToken = 'account-two';
      await reader.readMyAttempts();
      expect(
        transport.requests.last.headers['Authorization'],
        'Bearer account-two',
      );
    },
  );
}

TypeMatcher<ApiException> _error(ApiError kind) =>
    isA<ApiException>().having((error) => error.kind, 'kind', kind);

class _Tokens implements AccessTokenSource {
  @override
  String? accessToken = 'account-one';
}

class _Transport implements HttpTransport {
  final requests = <TransportRequest>[];
  Object? body;
  List<int>? raw;
  int status = 200;
  bool offline = false;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    if (offline) throw const TransportFailure();
    return TransportResponse(status, raw ?? utf8.encode(jsonEncode(body)));
  }
}
