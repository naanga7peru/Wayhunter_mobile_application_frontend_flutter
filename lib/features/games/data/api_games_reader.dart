import 'package:wayhunter_mobile/core/network/api_client.dart';

import '../domain/games_reader.dart';

class ApiGamesReader implements GamesReader {
  const ApiGamesReader(this._api);

  final ApiClient _api;
  static const _invalid = ApiException(ApiError.invalidResponse);

  @override
  Future<List<PublicGame>> readGames() async =>
      _list(await _get([]), (item) => _game(_object(item)));

  @override
  Future<PublicGameDetails?> readGame(String id) async {
    if (!isGameId(id)) throw ArgumentError.value(id, 'id', 'Expected a GUID');
    final Object? response;
    try {
      response = await _get([id]);
    } on ApiException catch (error) {
      if (error.kind == ApiError.notFound) return null;
      rethrow;
    }
    final dto = _object(response);
    final game = _game(dto);
    if (game.id.toLowerCase() != id.toLowerCase()) throw _invalid;
    return (game: game, stageCount: _count(dto, 'stageCount'));
  }

  @override
  Future<List<MyGameAttempt>> readMyAttempts() async =>
      _list(await _get(['me', 'attempts']), _attempt);

  Future<Object?> _get(List<String> path) => _api.request(ApiMethod.get, [
    'api',
    'mobile',
    'games',
    ...path,
  ], requiresSession: true);

  static PublicGame _game(Map<String, Object?> dto) {
    final title = _field<String>(dto, 'title');
    final minutes = _count(dto, 'durationMinutes');
    if (title.trim().isEmpty || minutes == 0) throw _invalid;
    return (
      id: _id(dto, 'gameId'),
      title: title,
      description: _field<String?>(dto, 'description'),
      durationMinutes: minutes,
      publishedAt: _date(_field<String>(dto, 'publishedAtUtc')),
      expiresAt: _date(_field<String>(dto, 'expiresAtUtc')),
    );
  }

  static MyGameAttempt _attempt(Object? item) {
    final dto = _object(item);
    final deadline = _field<String?>(dto, 'deadlineUtc');
    final status = switch (_field<int>(dto, 'status')) {
      0 => GameAttemptStatus.notStarted,
      1 => GameAttemptStatus.inProgress,
      2 => GameAttemptStatus.waitingForVerification,
      3 => GameAttemptStatus.completed,
      4 => GameAttemptStatus.rejected,
      _ => throw _invalid,
    };
    return (
      id: _id(dto, 'attemptId'),
      gameId: _id(dto, 'gameId'),
      startedAt: _date(_field<String>(dto, 'startedAtUtc')),
      deadline: deadline == null ? null : _date(deadline),
      status: status,
      currentStepNumber: _count(dto, 'currentStepNumber'),
      totalSteps: _count(dto, 'totalSteps'),
    );
  }

  static List<T> _list<T>(Object? value, T Function(Object?) decode) {
    if (value is! List<Object?>) throw _invalid;
    return List.unmodifiable(value.map(decode));
  }

  static Map<String, Object?> _object(Object? value) {
    if (value is Map<String, Object?>) return value;
    throw _invalid;
  }

  static T _field<T>(Map<String, Object?> dto, String key) {
    final value = dto[key];
    if (dto.containsKey(key) && value is T) return value;
    throw _invalid;
  }

  static String _id(Map<String, Object?> dto, String key) {
    final value = _field<String>(dto, key);
    if (!isGameId(value)) throw _invalid;
    return value;
  }

  static int _count(Map<String, Object?> dto, String key) {
    final value = _field<int>(dto, key);
    if (value < 0) throw _invalid;
    return value;
  }

  static DateTime _date(String value) {
    final date = DateTime.tryParse(value);
    if (date == null || !date.isUtc) throw _invalid;
    return date;
  }
}
