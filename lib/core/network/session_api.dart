import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';

/// Binds feature requests and their responses to one authenticated session.
class SessionApi {
  SessionApi(this._api, this._session) : _state = _session.state;

  final ApiClient _api;
  final SessionController _session;
  final SessionState _state;

  String? get owner => _state.user?.id;

  bool get isCurrent =>
      identical(_state, _session.state) &&
      _state.status == SessionStatus.authenticated &&
      owner != null &&
      _session.accessToken != null;

  Future<Object?> request(
    ApiMethod method,
    List<String> path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    if (!isCurrent) throw const ApiException(ApiError.unauthorized);
    try {
      return await _api.request(
        method,
        path,
        query: query,
        jsonBody: body,
        requiresSession: true,
      );
    } finally {
      if (!isCurrent) throw const ApiException(ApiError.unauthorized);
    }
  }
}
