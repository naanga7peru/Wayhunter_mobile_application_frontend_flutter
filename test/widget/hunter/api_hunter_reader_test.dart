import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/network/session_api.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/features/hunter/data/api_hunter_reader.dart';
import 'package:wayhunter_mobile/features/hunter/domain/hunter_history.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

import '../../foundation/api_client_test.dart' show FakeTransport;
import '../../foundation/session_and_device_test.dart'
    show MemoryCredentialStore;

const _id = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const _stamp = '2026-11-26T08:00:00+00:00';
const _path = '/api/mobile/hunter';
const _status = {
  'placeName': 'Test lookout',
  'district': 'Kandy',
  'status': 2,
  'createdAtUtc': _stamp,
  'submittedAtUtc': _stamp,
};
const _place = {
  'submissionId': _id,
  'placeName': 'Test trail',
  'district': 'Kandy',
  'latitude': 7.9,
  'longitude': 80.5,
  'approvedAtUtc': _stamp,
};

TransportResponse _json(Object? body, [int status = 200]) =>
    TransportResponse(status, utf8.encode(jsonEncode(body)));

Matcher _error(ApiError kind) =>
    isA<ApiException>().having((error) => error.kind, 'kind', kind);

void main() {
  late SessionController session;
  late ApiClient client;
  late FakeTransport transport;
  late Future<TransportResponse> Function(TransportRequest) respond;
  late ApiHunterReader reader;

  setUp(() async {
    session = SessionController(MemoryCredentialStore());
    addTearDown(session.dispose);
    await session.authenticate(
      const SessionCredential(
        user: UserRef('owner-one'),
        accessToken: 'hunter-test-one',
      ),
    );
    transport = FakeTransport((request) => respond(request));
    client = ApiClient(
      baseUrl: Uri.https('example.invalid'),
      transport: transport,
      tokens: session,
    );
    reader = ApiHunterReader(SessionApi(client, session));
  });

  test('discovery, owner list and status use authenticated GETs', () async {
    respond = (request) async => switch (request.uri.path) {
      '$_path/places' => _json([_place]),
      '$_path/submissions' => _json([
        {..._status, 'submissionId': _id},
      ]),
      '$_path/submissions/$_id' => _json({..._status, 'status': 3}),
      _ => throw StateError('Unexpected Hunter endpoint'),
    };
    expect((await reader.readPlaces()).single.district, 'Kandy');
    final hunt = (await reader.load()).single;
    expect(hunt.status, HuntStatus.held);
    expect(hunt.id, _id);
    expect((await reader.readStatus(hunt.id!)).status, HuntStatus.approved);
    expect(transport.requests, hasLength(3));
    for (final request in transport.requests) {
      expect(request.method, ApiMethod.get);
      expect(request.headers['Authorization'], 'Bearer hunter-test-one');
      expect(request.body, isNull);
    }
  });

  test(
    'discards a delayed response and rejects stale reads after account change',
    () async {
      final delayed = Completer<TransportResponse>();
      respond = (_) => delayed.future;
      final result = expectLater(
        reader.load(),
        throwsA(_error(ApiError.unauthorized)),
      );
      await session.authenticate(
        const SessionCredential(
          user: UserRef('owner-two'),
          accessToken: 'hunter-test-two',
        ),
      );
      delayed.complete(
        _json([
          {..._status, 'submissionId': _id},
        ]),
      );
      await result;
      await expectLater(
        reader.readPlaces(),
        throwsA(_error(ApiError.unauthorized)),
      );
      expect(transport.requests, hasLength(1));
      respond = (_) async => _json([]);
      expect(
        await ApiHunterReader(SessionApi(client, session)).load(),
        isEmpty,
      );
      expect(
        transport.requests.last.headers['Authorization'],
        'Bearer hunter-test-two',
      );
      await session.clear();
      await expectLater(
        ApiHunterReader(SessionApi(client, session)).load(),
        throwsA(_error(ApiError.unauthorized)),
      );
      expect(transport.requests, hasLength(2));
    },
  );

  test('rejects malformed DTOs and preserves owner-safe errors', () async {
    respond = (_) async => _json([
      {..._place, 'latitude': 91},
    ]);
    await expectLater(
      reader.readPlaces(),
      throwsA(_error(ApiError.invalidResponse)),
    );
    respond = (_) async => _json({..._status, 'status': 90});
    await expectLater(
      reader.readStatus(_id),
      throwsA(_error(ApiError.invalidResponse)),
    );
    for (final (code, kind) in [
      (401, ApiError.unauthorized),
      (403, ApiError.forbidden),
      (404, ApiError.notFound),
      (503, ApiError.server),
    ]) {
      respond = (_) async => _json(null, code);
      await expectLater(reader.readStatus(_id), throwsA(_error(kind)));
    }
  });
}
