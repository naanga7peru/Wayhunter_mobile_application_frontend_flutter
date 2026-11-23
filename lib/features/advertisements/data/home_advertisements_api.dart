import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/features/profile/data/my_profile_api.dart';

class HomeAdvertisement {
  const HomeAdvertisement({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.destinationUrl,
    required this.startAtUtc,
    required this.endAtUtc,
  });

  final String id;
  final String title;
  final Uri imageUrl;
  final Uri? destinationUrl;
  final DateTime startAtUtc;
  final DateTime endAtUtc;

  static HomeAdvertisement? eligible(Object? json) {
    if (json case {
      'id': final String id,
      'title': final String title,
      'imageUrl': final String image,
      'startAtUtc': final String start,
      'endAtUtc': final String end,
      'isEnabled': true,
      'placement': 1,
      'status': 1,
    }) {
      final url = safePublicHttpsUrl(image);
      final from = DateTime.tryParse(start);
      final to = DateTime.tryParse(end);
      if (id.isEmpty ||
          title.trim().isEmpty ||
          url == null ||
          from?.isUtc != true ||
          to?.isUtc != true ||
          !to!.isAfter(from!)) {
        return null;
      }
      final destination = (json as Map)['destinationUrl'];
      return HomeAdvertisement(
        id: id,
        title: title,
        imageUrl: url,
        destinationUrl: destination is String
            ? safePublicHttpsUrl(destination)
            : null,
        startAtUtc: from,
        endAtUtc: to,
      );
    }
    return null;
  }
}

class HomeAdvertisementsApi {
  const HomeAdvertisementsApi(this._api, this._session);

  final ApiClient _api;
  final SessionController _session;

  Future<List<HomeAdvertisement>> read() async {
    final token = _session.accessToken;
    final owner = _session.state.user?.id;
    if (token == null || owner == null) {
      throw const ApiException(ApiError.unauthorized);
    }
    final response = await _api.request(
      ApiMethod.get,
      ['api', 'mobile', 'advertisements', 'active'],
      query: {'placement': 'HomeBanner'},
      requiresSession: true,
    );
    if (_session.accessToken != token || _session.state.user?.id != owner) {
      throw const ApiException(ApiError.unauthorized);
    }
    if (response is! List<Object?>) {
      throw const ApiException(ApiError.invalidResponse);
    }
    return response
        .map(HomeAdvertisement.eligible)
        .nonNulls
        .toList(growable: false);
  }
}
