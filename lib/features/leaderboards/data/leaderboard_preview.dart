import 'package:flutter/foundation.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.user,
    required this.displayName,
    required this.position,
    this.score,
  });

  final UserRef user;
  final String displayName;
  final int position;
  final int? score;
}

typedef LeaderboardPreviewLoader =
    Future<List<LeaderboardEntry>> Function(ModuleId module);

const previewCurrentUser = UserRef('demo-ranking-current-user');

Future<List<LeaderboardEntry>> loadLeaderboardPreview(ModuleId module) async {
  if (!kDebugMode) return const [];

  final (leaderScore, currentScore) = switch (module) {
    ModuleId.traveler => (12, 9),
    ModuleId.hunter => (1000, 800),
    ModuleId.game => (700, 400),
  };

  return [
    LeaderboardEntry(
      user: const UserRef('demo-ranking-leader'),
      displayName: 'Sample Explorer',
      position: 1,
      score: leaderScore,
    ),
    LeaderboardEntry(
      user: previewCurrentUser,
      displayName: 'Sample Current User',
      position: 2,
      score: currentScore,
    ),
  ];
}
