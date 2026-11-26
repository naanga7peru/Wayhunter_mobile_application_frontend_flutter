typedef PublicGame = ({
  String id,
  String title,
  String? description,
  int durationMinutes,
  DateTime publishedAt,
  DateTime expiresAt,
});

typedef PublicGameDetails = ({PublicGame game, int stageCount});

enum GameAttemptStatus {
  notStarted('Not started'),
  inProgress('In progress'),
  waitingForVerification('Waiting for verification'),
  completed('Completed'),
  rejected('Rejected');

  const GameAttemptStatus(this.label);
  final String label;
}

typedef MyGameAttempt = ({
  String id,
  String gameId,
  DateTime startedAt,
  DateTime? deadline,
  GameAttemptStatus status,
  int currentStepNumber,
  int totalSteps,
});

enum GameCreationStatus {
  pending,
  approved,
  rejected,
  archived,
  draft,
  disabled,
}

class CreatedGameSummary {
  const CreatedGameSummary(
    this.title,
    this.status, {
    this.id,
    this.expiresAt,
    this.rejectionReason,
  });

  final String title;
  final GameCreationStatus status;
  final String? id;
  final DateTime? expiresAt;
  final String? rejectionReason;
}

abstract interface class GamesReader {
  Future<List<PublicGame>> readGames();
  Future<PublicGameDetails?> readGame(String id);
  Future<List<MyGameAttempt>> readMyAttempts();
}

final _guid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);
bool isGameId(String value) => value.length == 36 && _guid.hasMatch(value);
