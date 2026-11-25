import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

class IdentityApi {
  const IdentityApi(this._api);

  final ApiClient _api;
  static const _identity = ['api', 'mobile', 'identity'];
  static const otpCooldownSeconds = 60;
  static const recoveryConfirmation =
      'If the account is eligible, reset instructions will be sent.';

  Future<Object?> _post(String action, Map<String, String> body) =>
      _api.request(ApiMethod.post, [..._identity, action], jsonBody: body);

  Future<void> register(
    String displayName,
    String email,
    String password,
    String confirmPassword,
  ) async {
    final result = await _post('register', {
      'displayName': displayName,
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword,
    });
    if (result case {
      'userId': final String id,
      'displayName': String(),
      'requiresOtpVerification': true,
    } when isNavigationId(id)) {
      return;
    }
    throw const ApiException(ApiError.invalidResponse);
  }

  Future<void> verifyOtp(String email, String code) async {
    await _api.request(
      ApiMethod.post,
      [..._identity, 'verify-otp'],
      jsonBody: {'email': email, 'code': code},
      expectedSuccessStatus: 204,
    );
  }

  Future<void> resendOtp(String email) async {
    await _post('resend-otp', {'email': email});
  }

  Future<({SessionCredential credential, DateTime expiresAtUtc})> login(
    String email,
    String password,
  ) async {
    final result = await _post('login', {'email': email, 'password': password});
    if (result case {
      'userId': final String id,
      'accessToken': final String token,
      'expiresAtUtc': final String expiry,
    }) {
      final credential = SessionCredential(
        user: UserRef(id),
        accessToken: token,
      );
      final expiresAtUtc = DateTime.tryParse(expiry);
      if (credential.isValid && expiresAtUtc != null) {
        return (credential: credential, expiresAtUtc: expiresAtUtc.toUtc());
      }
    }
    throw const ApiException(ApiError.invalidResponse);
  }

  Future<void> forgotPassword(String email) async {
    await _post('forgot-password', {'email': email});
  }

  Future<void> resetPassword(
    String email,
    String token,
    String newPassword,
    String confirmPassword,
  ) async {
    await _post('reset-password', {
      'email': email,
      'token': token,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });
  }

  Future<UserRef> currentUser() async {
    final result = await _api.request(ApiMethod.get, [
      ..._identity,
      'me',
    ], requiresSession: true);
    if (result case {'userId': final String id} when isNavigationId(id)) {
      return UserRef(id);
    }
    throw const ApiException(ApiError.invalidResponse);
  }

  Future<void> revokeSession() async {
    await _api.request(ApiMethod.post, [
      'api',
      'mobile',
      'auth',
      'logout',
    ], requiresSession: true);
  }
}
