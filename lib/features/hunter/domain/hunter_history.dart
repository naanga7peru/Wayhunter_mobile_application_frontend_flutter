enum HuntStatus { draft, pending, held, approved, rejected }

typedef ApprovedHunterPlace = ({
  String id,
  String name,
  String district,
  num latitude,
  num longitude,
  DateTime approvedAt,
});

class HuntSummary {
  const HuntSummary({
    required this.name,
    required this.status,
    this.id,
    this.district,
    this.createdAt,
    this.submittedAt,
    this.reviewReason,
  });

  final String name;
  final HuntStatus status;
  final String? id;
  final String? district;
  final DateTime? createdAt;
  final DateTime? submittedAt;
  final String? reviewReason;
}

abstract interface class HunterHistory {
  Future<List<HuntSummary>> load();
}

class HunterHistoryUnavailable implements Exception {
  const HunterHistoryUnavailable();
}
