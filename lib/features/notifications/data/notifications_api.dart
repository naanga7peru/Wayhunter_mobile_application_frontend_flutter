import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/features/notifications/domain/notification_models.dart';

class NotificationsApi {
  NotificationsApi(this._api, this._session) : _owner = _session.state;

  final ApiClient _api;
  final SessionController _session;
  final SessionState _owner;
  static const _base = ['api', 'mobile', 'notifications'];
  static const inboxLimit = 30;

  void requireCurrent() {
    if (!identical(_session.state, _owner) ||
        _session.accessToken == null ||
        _owner.status != SessionStatus.authenticated) {
      throw const ApiException(ApiError.unauthorized);
    }
  }

  Future<Object?> _request(
    ApiMethod method,
    List<String> tail, {
    Map<String, String>? query,
    Object? body,
  }) async {
    requireCurrent();
    final response = await _api.request(
      method,
      [..._base, ...tail],
      requiresSession: true,
      query: query,
      jsonBody: body,
    );
    requireCurrent();
    return response;
  }

  Future<InboxPage> inbox() async => InboxPage.fromJson(
    await _request(ApiMethod.get, [], query: {'limit': '$inboxLimit'}),
  );

  Future<void> markRead(String id) async {
    if (!isNotificationId(id)) throw const ApiException(ApiError.notFound);
    await _request(ApiMethod.put, [id, 'read']);
  }

  Future<List<NotificationPreference>> preferences() async {
    final response = await _request(ApiMethod.get, ['preferences']);
    if (response is! List<Object?>) {
      throw const ApiException(ApiError.invalidResponse);
    }
    final choices = response
        .map(NotificationPreference.fromJson)
        .nonNulls
        .toList();
    if (choices.map((choice) => choice.category).toSet().length !=
        choices.length) {
      throw const ApiException(ApiError.invalidResponse);
    }
    return List.unmodifiable(choices);
  }

  Future<void> updatePreference(
    NotificationCategory category,
    bool enabled,
  ) async {
    await _request(
      ApiMethod.put,
      ['preferences'],
      body: {'category': category.code, 'pushEnabled': enabled},
    );
  }
}
