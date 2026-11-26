import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_plan.dart';

class TripPlansApi {
  TripPlansApi(this._api, this._session)
    : _token = _session.accessToken,
      _owner = _session.state.user?.id;

  final ApiClient _api;
  final SessionController _session;
  final String? _token;
  final String? _owner;

  static const _base = ['api', 'mobile', 'trip-plans'];

  void _checkOwner() {
    if (_token == null ||
        _owner == null ||
        _session.accessToken != _token ||
        _session.state.user?.id != _owner) {
      throw const ApiException(ApiError.unauthorized);
    }
  }

  Future<Object?> _request(
    ApiMethod method,
    List<String> path, {
    Object? body,
    String? ifMatch,
  }) async {
    _checkOwner();
    final response = await _api.request(
      method,
      [..._base, ...path],
      requiresSession: true,
      jsonBody: body,
      ifMatch: ifMatch,
    );
    _checkOwner();
    return response;
  }

  static String _id(String id) {
    if (!isTripPlanId(id)) throw const ApiException(ApiError.notFound);
    return id;
  }

  static TripPlan _decode(Object? response, [String? expected]) {
    final plan = TripPlan.fromJson(response);
    if (expected != null && plan.id.toLowerCase() != expected.toLowerCase()) {
      throw const ApiException(ApiError.invalidResponse);
    }
    return plan;
  }

  Future<List<TripPlan>> list() async {
    final response = await _request(ApiMethod.get, []);
    if (response is! List<Object?>) {
      throw const ApiException(ApiError.invalidResponse);
    }
    return response.map(_decode).toList(growable: false);
  }

  Future<TripPlan> get(String id) async =>
      _decode(await _request(ApiMethod.get, [_id(id)]), id);

  Future<TripPlan> create(TripInformation info, List<String> stops) async =>
      _decode(
        await _request(
          ApiMethod.post,
          [],
          body: {
            ...info.toJson(),
            'initialStops': [
              for (final name in stops) {'name': name},
            ],
          },
        ),
      );

  Future<TripPlan> update(TripPlan current, TripInformation info) async {
    if (!current.hasRowVersion) throw const ApiException(ApiError.unavailable);
    return _decode(
      await _request(
        ApiMethod.put,
        [_id(current.id)],
        body: {...info.toJson(), 'expectedRowVersion': current.rowVersion},
      ),
      current.id,
    );
  }

  Future<void> cancel(String id) async {
    await _request(ApiMethod.delete, [_id(id)]);
  }

  Future<TripPlan> addStop(TripPlan current, String name) async => _decode(
    await _request(
      ApiMethod.post,
      [_id(current.id), 'stops'],
      body: {
        'name': name,
        if (current.hasRowVersion) 'expectedRowVersion': current.rowVersion,
      },
    ),
    current.id,
  );

  Future<TripPlan> reorder(TripPlan current, List<String> stopIds) async =>
      _decode(
        await _request(
          ApiMethod.put,
          [_id(current.id), 'stops', 'order'],
          body: {
            'stopIds': stopIds.map(_id).toList(),
            if (current.hasRowVersion) 'expectedRowVersion': current.rowVersion,
          },
        ),
        current.id,
      );

  Future<TripPlan> removeStop(TripPlan current, String stopId) async => _decode(
    await _request(ApiMethod.delete, [
      _id(current.id),
      'stops',
      _id(stopId),
    ], ifMatch: current.hasRowVersion ? '"${current.rowVersion}"' : null),
    current.id,
  );
}
