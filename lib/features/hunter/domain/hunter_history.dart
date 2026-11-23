enum HuntStatus { pending, approved, rejected }

class HuntSummary {
  const HuntSummary({
    required this.name,
    required this.status,
    this.reviewReason,
  });

  final String name;
  final HuntStatus status;
  final String? reviewReason;
}

abstract interface class HunterHistory {
  Future<List<HuntSummary>> load();
}

class HunterHistoryUnavailable implements Exception {
  const HunterHistoryUnavailable();
}
