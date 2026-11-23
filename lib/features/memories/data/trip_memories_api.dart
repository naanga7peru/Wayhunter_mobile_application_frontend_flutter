import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/features/memories/domain/trip_memory.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_plan.dart';

class TripMemoriesApi {
  TripMemoriesApi(this._api, this._session)
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

  Future<List<TripMemory>> list(String tripId) async {
    final response = await _request(ApiMethod.get, tripId, []);
    if (response is! List<Object?>) {
      throw const ApiException(ApiError.invalidResponse);
    }
    return response
        .map((item) => _decode(item, expectedTripId: tripId))
        .toList(growable: false);
  }

  Future<TripMemory> get(String tripId, String memoryId) async => _decode(
    await _request(ApiMethod.get, tripId, [memoryId]),
    expectedTripId: tripId,
    expectedMemoryId: memoryId,
  );

  Future<TripMemory> create(
    String tripId, {
    required String operationId,
    required String caption,
    String? tripStopId,
  }) async {
    if (!isMemoryGuid(operationId) ||
        (tripStopId != null && !isMemoryGuid(tripStopId))) {
      throw const ApiException(ApiError.notFound);
    }
    return _decode(
      await _request(ApiMethod.post, tripId, [], {
        'operationId': operationId,
        'tripStopId': tripStopId,
        'caption': caption,
        'visibility': TripMemoryVisibility.private.wireValue,
      }),
      expectedTripId: tripId,
    );
  }

  Future<void> delete(String tripId, String memoryId) async {
    await _request(ApiMethod.delete, tripId, [memoryId]);
  }

  Future<Object?> _request(
    ApiMethod method,
    String tripId,
    List<String> tail, [
    Object? body,
  ]) async {
    _requireAccount();
    if (!isTripPlanId(tripId) || tail.any((id) => !isMemoryGuid(id))) {
      throw const ApiException(ApiError.notFound);
    }
    final result = await _api.request(
      method,
      ['api', 'mobile', 'trips', tripId, 'memories', ...tail],
      jsonBody: body,
      requiresSession: true,
    );
    _requireAccount();
    return result;
  }

  void _requireAccount() {
    if (!isCurrentAccount) throw const ApiException(ApiError.unauthorized);
  }

  static TripMemory _decode(
    Object? value, {
    required String expectedTripId,
    String? expectedMemoryId,
  }) {
    final memory = TripMemory.fromJson(value);
    if (memory.tripPlanId.toLowerCase() != expectedTripId.toLowerCase() ||
        (expectedMemoryId != null &&
            memory.id.toLowerCase() != expectedMemoryId.toLowerCase())) {
      throw const ApiException(ApiError.invalidResponse);
    }
    return memory;
  }
}
