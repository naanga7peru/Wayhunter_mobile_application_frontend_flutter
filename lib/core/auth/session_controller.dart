import 'package:flutter/foundation.dart';
import 'package:wayhunter_mobile/core/auth/access_token_source.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

enum SessionStatus { signedOut, restoring, authenticated, expired }

class SessionState {
  const SessionState._(this.status, [this.user]);

  final SessionStatus status;
  final UserRef? user;
}

class SessionOperationSupersededException implements Exception {
  const SessionOperationSupersededException();
}

class CredentialReplacementCleanupException extends CredentialStorageException {
  const CredentialReplacementCleanupException(this.writeError, this.clearError);

  final Object writeError;
  final Object clearError;
}

class SessionController extends ChangeNotifier implements AccessTokenSource {
  SessionController(this._store);

  final CredentialStore _store;
  SessionState _state = const SessionState._(SessionStatus.signedOut);
  SessionCredential? _credential;
  SessionState? _rejectedState;
  Future<void> _pending = Future<void>.value();
  Future<void>? _restoration;
  int _generation = 0;
  bool _canRestore = true;

  SessionState get state => _state;
  bool get currentSessionRejected => identical(_rejectedState, _state);

  /// Captures the identity of the request's session, even if a later sign-in
  /// receives the same token string.
  void Function() captureUnauthorizedHandler() {
    final requestState = _state;
    final generation = _generation;
    return () {
      if (generation == _generation &&
          identical(requestState, _state) &&
          _state.status == SessionStatus.authenticated &&
          !currentSessionRejected) {
        _rejectedState = requestState;
        notifyListeners();
      }
    };
  }

  @override
  String? get accessToken => _credential?.accessToken;

  /// Reads the locally saved session once. The API still decides authorization.
  Future<void> restore() {
    final inFlight = _restoration;
    if (inFlight != null) return inFlight;
    if (!_canRestore) return Future<void>.value();
    _canRestore = false;
    final generation = ++_generation;
    final operation = _enqueue(() async {
      try {
        final restored = await _store.read();
        if (generation != _generation) return;
        if (restored != null && !restored.isValid) {
          throw const CredentialStorageException();
        }
        _publishCredential(restored);
      } on CredentialStorageException {
        if (generation == _generation) {
          _canRestore = true;
          _setState(SessionStatus.signedOut);
        }
        rethrow;
      }
    }).whenComplete(() => _restoration = null);
    _restoration = operation;
    _setState(SessionStatus.restoring);
    return operation;
  }

  /// Clears the old durable credential before saving a server-issued replacement.
  /// Each storage failure is returned to the caller.
  Future<void> authenticate(SessionCredential credential) {
    if (!credential.isValid) throw ArgumentError('Invalid session credential.');
    _canRestore = false;
    final generation = ++_generation;
    final operation = _enqueue(() async {
      _requireCurrent(generation);
      await _store.clear();
      _requireCurrent(generation);
      try {
        await _store.write(credential);
      } catch (writeError) {
        // A failed write may have partially persisted the new credential.
        try {
          await _store.clear();
        } catch (clearError) {
          throw CredentialReplacementCleanupException(writeError, clearError);
        }
        rethrow;
      }
      if (generation != _generation) {
        await _store.clear();
        throw const SessionOperationSupersededException();
      }
      _publishCredential(credential);
    });
    _publishCredential(null);
    return operation;
  }

  void _requireCurrent(int generation) {
    if (generation != _generation) {
      throw const SessionOperationSupersededException();
    }
  }

  Future<void> clear() => _endSession(SessionStatus.signedOut);

  Future<void> expire() => _endSession(SessionStatus.expired);

  Future<void> _endSession(SessionStatus status) {
    ++_generation;
    _canRestore = false;
    final deletion = _enqueue(_store.clear);
    _credential = null;
    _setState(status);
    return deletion;
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace stack) {},
    );
    return operation;
  }

  void _publishCredential(SessionCredential? credential) {
    _credential = credential;
    _setState(
      credential == null
          ? SessionStatus.signedOut
          : SessionStatus.authenticated,
      credential?.user,
    );
  }

  void _setState(SessionStatus status, [UserRef? user]) {
    _state = SessionState._(status, user);
    _rejectedState = null;
    notifyListeners();
  }

  @override
  void dispose() {
    ++_generation;
    super.dispose();
  }
}
