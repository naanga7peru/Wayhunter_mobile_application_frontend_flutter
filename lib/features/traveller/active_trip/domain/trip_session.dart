import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_plan.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

enum TripSessionStatus {
  active('Active'),
  paused('Paused'),
  finished('Finished');

  const TripSessionStatus(this.label);
  final String label;
}

enum TripSessionAction {
  pause('Pause trip', TripSessionStatus.paused),
  resume('Resume trip', TripSessionStatus.active),
  finish('Finish trip', TripSessionStatus.finished);

  const TripSessionAction(this.label, this.result);
  final String label;
  final TripSessionStatus result;

  bool allows(TripSessionStatus status) => switch (this) {
    pause => status == TripSessionStatus.active,
    resume => status == TripSessionStatus.paused,
    finish => status != TripSessionStatus.finished,
  };
}

class TripSession {
  const TripSession({
    required this.reference,
    required this.status,
    required this.startedAtUtc,
    required this.finishedAtUtc,
  });

  final ActiveTripArgs reference;
  final TripSessionStatus status;
  final DateTime startedAtUtc;
  final DateTime? finishedAtUtc;

  factory TripSession.fromJson(Object? json) {
    if (json case {
      'tripPlanId': final String plan,
      'sessionId': final String session,
      'status': final int value,
      'startedAtUtc': final String start,
      'finishedAtUtc': final String? finish,
    } when isTripPlanId(plan) && isTripPlanId(session)) {
      final status = switch (value) {
        1 => TripSessionStatus.active,
        2 => TripSessionStatus.paused,
        3 => TripSessionStatus.finished,
        _ => null,
      };
      final started = _utc(start);
      final finished = finish == null ? null : _utc(finish);
      if (status != null &&
          started != null &&
          (status == TripSessionStatus.finished
              ? finished != null && !finished.isBefore(started)
              : finish == null)) {
        return TripSession(
          reference: ActiveTripArgs(
            plan: TripPlanRef(plan),
            session: TripSessionRef(session),
          ),
          status: status,
          startedAtUtc: started,
          finishedAtUtc: finished,
        );
      }
    }
    throw const ApiException(ApiError.invalidResponse);
  }

  static DateTime? _utc(String value) {
    final date = DateTime.tryParse(value);
    return date?.isUtc == true ? date : null;
  }
}
