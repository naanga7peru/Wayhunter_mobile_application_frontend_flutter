import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

class AndroidCredentialStore implements CredentialStore {
  AndroidCredentialStore({
    required String namespace,
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
    ),
  }) : _key = 'wayhunter.session.$namespace',
       _storage = storage;

  final String _key;
  final FlutterSecureStorage _storage;

  @override
  Future<SessionCredential?> read() => _storageOperation(() async {
    final encoded = await _storage.read(key: _key);
    if (encoded == null) return null;
    final data = jsonDecode(encoded);
    if (data case {
      'userId': final String id,
      'accessToken': final String token,
    }) {
      final credential = SessionCredential(
        user: UserRef(id),
        accessToken: token,
      );
      if (credential.isValid) return credential;
    }
    throw const CredentialStorageException();
  });

  @override
  Future<void> write(SessionCredential credential) =>
      _storageOperation(() async {
        if (!credential.isValid) throw const CredentialStorageException();
        await _storage.write(
          key: _key,
          value: jsonEncode({
            'userId': credential.user.id,
            'accessToken': credential.accessToken,
          }),
        );
      });

  @override
  Future<void> clear() => _storageOperation(() => _storage.delete(key: _key));

  Future<T> _storageOperation<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException {
      throw const CredentialStorageException();
    } on MissingPluginException {
      throw const CredentialStorageException();
    } on FormatException {
      throw const CredentialStorageException();
    }
  }
}
