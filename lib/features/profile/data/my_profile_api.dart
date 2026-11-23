import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';

class MyProfile {
  const MyProfile({
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.bio,
    required this.phoneNumber,
  });

  final String displayName;
  final String email;
  final Uri? avatarUrl;
  final String? bio;
  final String? phoneNumber;
}

Uri? safePublicHttpsUrl(String? value) {
  if (value == null ||
      value.isEmpty ||
      value.length > 2048 ||
      value != value.trim() ||
      RegExp(r'[\\\x00-\x20\x7f-\x9f]').hasMatch(value)) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.port != 443 ||
      uri.authority.contains('@')) {
    return null;
  }
  final host = uri.host.toLowerCase();
  final labels = host.split('.');
  final label = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
  if (labels.length < 2 ||
      !labels.every(label.hasMatch) ||
      !RegExp(r'^[a-z]').hasMatch(labels.last) ||
      const {'localhost', 'local', 'internal'}.contains(labels.last)) {
    return null;
  }
  return uri;
}

class MyProfileApi {
  const MyProfileApi(this._api, this._session);

  final ApiClient _api;
  final SessionController _session;

  Future<MyProfile?> read() async {
    final token = _session.accessToken;
    final owner = _session.state.user?.id;
    if (token == null || owner == null) {
      throw const ApiException(ApiError.unauthorized);
    }
    final response = await _api.request(ApiMethod.get, [
      'api',
      'mobile',
      'identity',
      'me',
    ], requiresSession: true);
    if (_session.accessToken != token || _session.state.user?.id != owner) {
      throw const ApiException(ApiError.unauthorized);
    }
    if (response == null) return null;
    if (response case {
      'userId': final String userId,
      'displayName': final String displayName,
      'email': final String email,
    }) {
      if (userId != owner) throw const ApiException(ApiError.forbidden);
      final fields = response as Map;
      final avatar = fields['avatarUrl'];
      final bio = fields['bio'];
      final phone = fields['phoneNumber'];
      if (displayName.trim().isNotEmpty &&
          email.trim().isNotEmpty &&
          (avatar == null || avatar is String) &&
          (bio == null || bio is String) &&
          (phone == null || phone is String)) {
        return MyProfile(
          displayName: displayName,
          email: email,
          avatarUrl: safePublicHttpsUrl(avatar as String?),
          bio: bio as String?,
          phoneNumber: phone as String?,
        );
      }
    }
    throw const ApiException(ApiError.invalidResponse);
  }
}
