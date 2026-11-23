import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/domain/trip_session.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_plan.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

/// Scoped to the authenticated shell. Never persists session references.
class TripSessionsApi {
  TripSessionsApi(this._api, this._session)
    : _token = _session.accessToken,
      _owner = _session.state.user?.id;

  final ApiClient _api;
  final SessionController _session;
  final String? _token;
  final String? _owner;
  final _known = <String, TripSession>{};
  final _uncertainStarts = <String>{};
  final _running = <String>{};

  bool belongsTo(SessionController session) =>
      identical(session, _session) &&
      _token != null &&
      _owner != null &&
      session.accessToken == _token &&
      session.state.user?.id == _owner;

  TripSession? known(TripPlanRef plan) =>
      belongsTo(_session) ? _known[plan.id.toLowerCase()] : null;

  bool startNeedsVerification(TripPlanRef plan) =>
      belongsTo(_session) && _uncertainStarts.contains(plan.id.toLowerCase());

  static bool needsReconciliation(ApiException error) => switch (error.kind) {
    ApiError.timeout ||
    ApiError.network ||
    ApiError.server ||
    ApiError.invalidResponse ||
    ApiError.conflict => true,
    _ => false,
  };

  Future<TripSession> start(TripPlanRef plan) async {
    _requireAccess();
    final key = plan.id.toLowerCase();
    final existing = known(plan);
    if (existing != null) return existing;
    if (_uncertainStarts.contains(key) || _running.contains(key)) {
      throw const ApiException(ApiError.conflict);
    }
    try {
      return await _request(
        plan,
        ApiMethod.post,
        [],
        null,
        (status) => status != TripSessionStatus.finished,
      );
    } on ApiException catch (error) {
      if (belongsTo(_session) && needsReconciliation(error)) {
        _uncertainStarts.add(key);
      }
      rethrow;
    }
  }

  Future<TripSession> recover(ActiveTripArgs args) => _request(
    args.plan,
    ApiMethod.get,
    ['recover'],
    args.session,
    (status) => status != TripSessionStatus.finished,
  );

  Future<TripSession> change(ActiveTripArgs args, TripSessionAction action) =>
      _request(
        args.plan,
        ApiMethod.post,
        [action.name],
        args.session,
        (status) => status == action.result,
      );

  void _requireAccess() {
    if (!belongsTo(_session)) throw const ApiException(ApiError.unauthorized);
  }

  Future<TripSession> _request(
    TripPlanRef plan,
    ApiMethod method,
    List<String> tail,
    TripSessionRef? session,
    bool Function(TripSessionStatus) accepts,
  ) async {
    _requireAccess();
    if (!isTripPlanId(plan.id) ||
        (session != null && !isTripPlanId(session.id))) {
      throw const ApiException(ApiError.notFound);
    }
    final key = plan.id.toLowerCase();
    if (!_running.add(key)) throw const ApiException(ApiError.conflict);
    try {
      final response = await _api.request(method, [
        'api',
        'mobile',
        'trips',
        plan.id,
        'sessions',
        if (session != null) session.id,
        ...tail,
      ], requiresSession: true);
      _requireAccess();
      final result = TripSession.fromJson(response);
      if (result.reference.plan.id.toLowerCase() != key ||
          (session != null &&
              result.reference.session.id.toLowerCase() !=
                  session.id.toLowerCase()) ||
          !accepts(result.status)) {
        throw const ApiException(ApiError.invalidResponse);
      }
      _known[key] = result;
      _uncertainStarts.remove(key);
      return result;
    } finally {
      _running.remove(key);
    }
  }
}
