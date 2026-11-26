import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/network/session_api.dart';

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
  MyProfileApi(ApiClient api, SessionController session)
    : _sessionApi = SessionApi(api, session);

  final SessionApi _sessionApi;
  static const _path = ['api', 'mobile', 'identity', 'me'];

  Future<MyProfile?> read() async {
    final response = await _sessionApi.request(ApiMethod.get, _path);
    return response == null ? null : _decode(response);
  }

  Future<MyProfile> update({required String displayName, String? bio}) async {
    final name = displayName.trim();
    if (name.isEmpty || name.length > 200 || (bio?.length ?? 0) > 500) {
      throw const ApiException(ApiError.rejected);
    }
    return _decode(
      await _sessionApi.request(
        ApiMethod.put,
        _path,
        body: {'displayName': name, 'bio': bio},
      ),
    );
  }

  MyProfile _decode(Object? response) {
    if (response case {
      'userId': final String userId,
      'displayName': final String displayName,
      'email': final String email,
    }) {
      if (userId != _sessionApi.owner) {
        throw const ApiException(ApiError.forbidden);
      }
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
