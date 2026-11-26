import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';

/// A pending Start uses [pendingTripStart]. A pending Finish stores its
/// session ID so the client can read that session before any further mutation.
const pendingTripStart = 'start';

abstract interface class TripRecoveryStore {
  Future<String?> read(String owner, String trip);
  Future<void> write(String owner, String trip, String? pending);
}

class SecureTripRecoveryStore implements TripRecoveryStore {
  const SecureTripRecoveryStore(this._namespace);

  final String _namespace;
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  String _key(String owner, String trip) =>
      'wayhunter.trip-recovery.$_namespace.$owner.$trip';

  @override
  Future<String?> read(String owner, String trip) =>
      _access(() => _storage.read(key: _key(owner, trip)));

  @override
  Future<void> write(String owner, String trip, String? pending) => _access(
    () => pending == null
        ? _storage.delete(key: _key(owner, trip))
        : _storage.write(key: _key(owner, trip), value: pending),
  );

  Future<T> _access<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException {
      throw const ApiException(ApiError.unavailable);
    } on MissingPluginException {
      throw const ApiException(ApiError.unavailable);
    }
  }
}
