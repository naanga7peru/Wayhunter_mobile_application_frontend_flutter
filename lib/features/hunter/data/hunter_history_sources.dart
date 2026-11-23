import 'package:wayhunter_mobile/features/hunter/domain/hunter_history.dart';

class UnavailableHunterHistory implements HunterHistory {
  const UnavailableHunterHistory();

  @override
  Future<List<HuntSummary>> load() async =>
      throw const HunterHistoryUnavailable();
}

class DemoHunterHistory implements HunterHistory {
  const DemoHunterHistory();

  @override
  Future<List<HuntSummary>> load() async => const [
    HuntSummary(name: 'Sample forest lookout', status: HuntStatus.pending),
    HuntSummary(name: 'Sample garden trail', status: HuntStatus.approved),
    HuntSummary(
      name: 'Sample lakeside path',
      status: HuntStatus.rejected,
      reviewReason:
          'Sample reason: The live photo did not show the place clearly.',
    ),
  ];
}
