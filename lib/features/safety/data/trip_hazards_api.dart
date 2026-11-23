import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/features/safety/domain/hazard_warning.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_plan.dart';

class TripHazardsApi {
  TripHazardsApi(this._api, this._session)
    : _token = _session.accessToken,
      _owner = _session.state.user?.id;

  final ApiClient _api;
  final SessionController _session;
  final String? _token;
  final String? _owner;

  bool get isCurrentAccount =>
      _token != null &&
      _owner != null &&
      _session.accessToken == _token &&
      _session.state.user?.id == _owner;

  Future<List<HazardWarning>> listForTrip(String tripPlanId) async {
    _checkAccount();
    if (!isTripPlanId(tripPlanId)) {
      throw const ApiException(ApiError.notFound);
    }
    final response = await _api.request(ApiMethod.get, [
      'api',
      'mobile',
      'trips',
      tripPlanId,
      'hazards',
    ], requiresSession: true);
    _checkAccount();
    if (response is! List<Object?>) {
      throw const ApiException(ApiError.invalidResponse);
    }
    return response.map(HazardWarning.fromJson).toList(growable: false);
  }

  void _checkAccount() {
    if (!isCurrentAccount) throw const ApiException(ApiError.unauthorized);
  }
}
