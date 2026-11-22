import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/services/device_interfaces.dart';
import 'package:wayhunter_mobile/core/storage/android_credential_store.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

class MemoryCredentialStore implements CredentialStore {
  MemoryCredentialStore([this.saved]);

  SessionCredential? saved;
  Completer<SessionCredential?>? pendingRead;
  Completer<void>? pendingWrite;
  bool failClear = false;
  bool failWrite = false;
  bool persistBeforeWriteFailure = false;
  bool failClearAfterWrite = false;
  int readCount = 0;
  int writeCount = 0;

  @override
  Future<SessionCredential?> read() async {
    readCount++;
    return pendingRead == null ? saved : await pendingRead!.future;
  }

  @override
  Future<void> write(SessionCredential credential) async {
    writeCount++;
    if (pendingWrite case final completion?) await completion.future;
    if (failWrite) {
      if (persistBeforeWriteFailure) saved = credential;
      if (failClearAfterWrite) failClear = true;
      throw const CredentialStorageException();
    }
    saved = credential;
  }

  @override
  Future<void> clear() async {
    if (failClear) throw const CredentialStorageException();
    saved = null;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const credential = SessionCredential(
    user: UserRef('user-1'),
    accessToken: 'fixture-token',
  );
  const replacement = SessionCredential(
    user: UserRef('user-2'),
    accessToken: 'fixture-replacement-token',
  );

  test(
    'session restores, expires, and can authenticate and clear again',
    () async {
      final storage = MemoryCredentialStore(credential);
      final session = SessionController(storage);
      addTearDown(session.dispose);
      expect(session.state.status, SessionStatus.signedOut);

      final restoration = session.restore();
      expect(session.state.status, SessionStatus.restoring);
      expect(session.accessToken, isNull);
      await restoration;
      expect(session.state.status, SessionStatus.authenticated);
      expect(session.state.user?.id, credential.user.id);
      expect(session.accessToken, credential.accessToken);

      final expiry = session.expire();
      expect(session.state.status, SessionStatus.expired);
      expect(session.accessToken, isNull);
      await expiry;
      expect(storage.saved, isNull);

      await session.authenticate(credential);
      expect(storage.saved, same(credential));
      expect(session.state.status, SessionStatus.authenticated);
      await session.clear();
      expect(session.state.status, SessionStatus.signedOut);
      expect(session.state.user, isNull);
      expect(session.accessToken, isNull);
      expect(storage.saved, isNull);
    },
  );

  test(
    'clear prevents an in-flight restore from reviving the session',
    () async {
      final storage = MemoryCredentialStore()..pendingRead = Completer();
      final session = SessionController(storage);
      addTearDown(session.dispose);
      final restoration = session.restore();
      await Future<void>.delayed(Duration.zero);
      final clearing = session.clear();
      storage.pendingRead!.complete(credential);

      await restoration;
      await clearing;
      expect(session.state.status, SessionStatus.signedOut);
      expect(session.accessToken, isNull);
      expect(storage.saved, isNull);
    },
  );

  test(
    'storage failures leave the session unusable and surface to callers',
    () async {
      final storage = MemoryCredentialStore();
      final session = SessionController(storage);
      addTearDown(session.dispose);
      await session.authenticate(credential);
      storage.failClear = true;
      await expectLater(
        session.clear(),
        throwsA(isA<CredentialStorageException>()),
      );
      expect(session.accessToken, isNull);
      expect(session.state.status, SessionStatus.signedOut);
      await session.restore();
      expect(session.accessToken, isNull);
      storage.failClear = false;
      await session.clear();
      expect(storage.saved, isNull);
    },
  );

  test('concurrent restore callers await the same storage read', () async {
    final storage = MemoryCredentialStore()..pendingRead = Completer();
    final session = SessionController(storage);
    addTearDown(session.dispose);

    final first = session.restore();
    final second = session.restore();
    expect(second, same(first));
    expect(session.state.status, SessionStatus.restoring);
    storage.pendingRead!.complete(credential);

    await Future.wait([first, second]);
    expect(storage.readCount, 1);
    expect(session.state.user?.id, credential.user.id);
  });

  test('failed User B replacement cannot restore User A on restart', () async {
    final storage = MemoryCredentialStore(credential);
    final session = SessionController(storage);
    addTearDown(session.dispose);
    await session.restore();
    expect(session.state.user?.id, credential.user.id);

    storage.failWrite = true;
    await expectLater(
      session.authenticate(replacement),
      throwsA(isA<CredentialStorageException>()),
    );
    expect(session.state.status, SessionStatus.signedOut);
    expect(session.accessToken, isNull);
    expect(storage.saved, isNull);

    final restarted = SessionController(storage);
    addTearDown(restarted.dispose);
    await restarted.restore();
    expect(restarted.state.status, SessionStatus.signedOut);
    expect(restarted.state.user, isNull);
    expect(restarted.accessToken, isNull);
  });

  test('replacement clear failure is surfaced before any write', () async {
    final storage = MemoryCredentialStore(credential)..failClear = true;
    final session = SessionController(storage);
    addTearDown(session.dispose);
    await session.restore();

    await expectLater(
      session.authenticate(replacement),
      throwsA(isA<CredentialStorageException>()),
    );
    expect(storage.writeCount, 0);
    expect(storage.saved, same(credential));
    expect(session.state.status, SessionStatus.signedOut);
    expect(session.accessToken, isNull);
    await session.restore();
    expect(session.state.user, isNull);

    storage.failClear = false;
    await session.clear();
    final restarted = SessionController(storage);
    addTearDown(restarted.dispose);
    await restarted.restore();
    expect(restarted.accessToken, isNull);
  });

  test('failed writes clean up a partially persisted replacement', () async {
    final storage = MemoryCredentialStore(credential)
      ..failWrite = true
      ..persistBeforeWriteFailure = true;
    final session = SessionController(storage);
    addTearDown(session.dispose);
    await session.restore();

    await expectLater(
      session.authenticate(replacement),
      throwsA(isA<CredentialStorageException>()),
    );
    expect(storage.saved, isNull);
    expect(session.accessToken, isNull);
  });

  test('failed write and cleanup both surface to the caller', () async {
    final storage = MemoryCredentialStore(credential)
      ..failWrite = true
      ..persistBeforeWriteFailure = true
      ..failClearAfterWrite = true;
    final session = SessionController(storage);
    addTearDown(session.dispose);
    await session.restore();

    await expectLater(
      session.authenticate(replacement),
      throwsA(
        isA<CredentialReplacementCleanupException>()
            .having(
              (error) => error.writeError,
              'write error',
              isA<CredentialStorageException>(),
            )
            .having(
              (error) => error.clearError,
              'clear error',
              isA<CredentialStorageException>(),
            ),
      ),
    );
    expect(session.state.status, SessionStatus.signedOut);
    expect(session.accessToken, isNull);
  });

  test('clear supersedes an authentication queued behind restore', () async {
    final storage = MemoryCredentialStore(credential)
      ..pendingRead = Completer();
    final session = SessionController(storage);
    addTearDown(session.dispose);
    final restoration = session.restore();
    await Future<void>.delayed(Duration.zero);

    final authentication = expectLater(
      session.authenticate(replacement),
      throwsA(isA<SessionOperationSupersededException>()),
    );
    final clearing = session.clear();
    storage.pendingRead!.complete(credential);

    await Future.wait([restoration, authentication, clearing]);
    expect(storage.writeCount, 0);
    expect(storage.saved, isNull);
    expect(session.state.status, SessionStatus.signedOut);
    expect(session.accessToken, isNull);
  });

  test(
    'clear during a write prevents publication and removes the saved token',
    () async {
      final storage = MemoryCredentialStore(credential)
        ..pendingWrite = Completer();
      final session = SessionController(storage);
      addTearDown(session.dispose);
      await session.restore();

      final authentication = expectLater(
        session.authenticate(replacement),
        throwsA(isA<SessionOperationSupersededException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(storage.writeCount, 1);
      expect(storage.saved, isNull);
      expect(session.accessToken, isNull);

      final clearing = session.clear();
      storage.pendingWrite!.complete();
      await Future.wait([authentication, clearing]);
      expect(storage.saved, isNull);
      expect(session.state.status, SessionStatus.signedOut);
      expect(session.accessToken, isNull);
    },
  );

  test('unavailable storage never persists a credential', () async {
    final session = SessionController(const UnavailableCredentialStore());
    addTearDown(session.dispose);
    await expectLater(
      session.restore(),
      throwsA(isA<CredentialStorageException>()),
    );
    await expectLater(
      session.authenticate(credential),
      throwsA(isA<CredentialStorageException>()),
    );
    expect(session.state.status, SessionStatus.signedOut);
    expect(session.accessToken, isNull);
  });

  test(
    'Android storage delegates to secure platform channel and scopes keys',
    () async {
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      final values = <String, String>{};
      final messenger = binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (message) async {
        final key = message.arguments['key'] as String;
        return switch (message.method) {
          'read' => values[key],
          'write' => values[key] = message.arguments['value'] as String,
          'delete' => values.remove(key),
          _ => throw MissingPluginException(),
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final staging = AndroidCredentialStore(namespace: 'staging');
      final production = AndroidCredentialStore(namespace: 'production');
      await staging.write(credential);
      expect(values.keys, ['wayhunter.session.staging']);
      expect((await staging.read())?.accessToken, credential.accessToken);
      expect(await production.read(), isNull);
      values['wayhunter.session.staging'] = 'bad data';
      await expectLater(
        staging.read(),
        throwsA(isA<CredentialStorageException>()),
      );
      await staging.clear();
      expect(await staging.read(), isNull);
    },
  );

  test(
    'unavailable device adapter produces explicit states and no sample data',
    () async {
      const device = UnavailableDeviceServices();
      expect(
        await device.check(DevicePermission.location),
        DevicePermissionStatus.unavailable,
      );
      expect(
        await device.request(DevicePermission.camera),
        DevicePermissionStatus.unavailable,
      );
      expect(await device.availability(), MapProviderStatus.unavailable);
      expect(
        await device.status('test-operation'),
        MediaUploadStatus.unavailable,
      );
      await expectLater(
        device.read(),
        throwsA(isA<DeviceUnavailableException>()),
      );
      await expectLater(
        device.takePhoto(),
        throwsA(isA<DeviceUnavailableException>()),
      );
      await expectLater(
        device.recordVideo(),
        throwsA(isA<DeviceUnavailableException>()),
      );
    },
  );
}
