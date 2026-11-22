import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

class SessionCredential {
  const SessionCredential({required this.user, required this.accessToken});

  final UserRef user;
  final String accessToken;

  bool get isValid =>
      isNavigationId(user.id) &&
      accessToken.isNotEmpty &&
      !RegExp(r'[^\x21-\x7E]').hasMatch(accessToken);
}

abstract interface class CredentialStore {
  Future<SessionCredential?> read();
  Future<void> write(SessionCredential credential);
  Future<void> clear();
}

class CredentialStorageException implements Exception {
  const CredentialStorageException();
}

class UnavailableCredentialStore implements CredentialStore {
  const UnavailableCredentialStore();

  @override
  Future<SessionCredential?> read() async =>
      throw const CredentialStorageException();

  @override
  Future<void> write(SessionCredential credential) async =>
      throw const CredentialStorageException();

  @override
  Future<void> clear() async => throw const CredentialStorageException();
}
