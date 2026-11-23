import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/features/wallet/data/repositories/api_voucher_redemption_repository.dart';
import 'package:wayhunter_mobile/features/wallet/domain/voucher_redemption.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

const _id = 'a7ea80d9-4102-4d86-96a1-27879ba5bc90';
const _offer = '52ad9d02-9ca1-4c48-bacc-6a08b7de8c17';
const _path = '/api/mobile/coins-wallet/vouchers/requests';
const _time = '2026-11-23T10:00:00.1234567+00:00';

class _Store implements CredentialStore {
  @override
  Future<void> clear() async {}

  @override
  Future<SessionCredential?> read() async => null;

  @override
  Future<void> write(SessionCredential credential) async {}
}

class _Transport implements HttpTransport {
  final calls = <TransportRequest>[];
  FutureOr<TransportResponse> Function(TransportRequest) respond = (_) =>
      const TransportResponse(204, []);

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    calls.add(request);
    return respond(request);
  }
}

TransportResponse _json(Object? value, {int status = 200}) =>
    TransportResponse(status, utf8.encode(jsonEncode(value)));

Map<String, Object?> _request({String id = _id, int status = 1}) => {
  'requestId': id,
  'offerId': _offer,
  'ownerUserId': 'owner',
  'ownerName': 'Synthetic Owner',
  'costCoins': 10000,
  'status': status,
  'requestedAtUtc': _time,
  'decidedAtUtc': status == 1 ? null : _time,
  'decisionReason': status == 1 ? null : 'Synthetic decision',
};

Map<String, Object?> _voucher(int status) => {
  'requestId': _id,
  'status': status,
  'referenceValueLkr': 100.0,
  'voucherCode': status == 3 || status == 4 ? 'fixture-code' : null,
  'qrPayload': status == 3 || status == 4 ? 'fixture-payload' : null,
  'sampleImageReference': status == 3 || status == 4 ? 'fixture-image' : null,
  'issuedAtUtc': status >= 3 ? _time : null,
  'expiresAtUtc': status >= 3 ? '2026-12-23T10:00:00+00:00' : null,
  'usedAtUtc': status == 4 ? _time : null,
};

Matcher _error(ApiError kind, {int? status}) => isA<ApiException>()
    .having((error) => error.kind, 'kind', kind)
    .having((error) => error.statusCode, 'statusCode', status);

void main() {
  late SessionController session;
  late _Transport transport;
  late ApiClient api;
  late ApiVoucherRedemptionRepository repo;
  late ApiVoucherRedemptionRepository enabled;

  Future<void> signIn(String owner) => session.authenticate(
    SessionCredential(user: UserRef(owner), accessToken: 'fixture-$owner'),
  );

  ApiClient client({
    Uri? baseUrl,
    Duration timeout = const Duration(seconds: 2),
  }) => ApiClient(
    baseUrl: baseUrl,
    transport: transport,
    tokens: session,
    timeout: timeout,
  );

  setUp(() async {
    session = SessionController(_Store());
    await signIn('owner');
    transport = _Transport();
    api = client(baseUrl: Uri.parse('https://example.invalid'));
    repo = ApiVoucherRedemptionRepository(api, session);
    enabled = ApiVoucherRedemptionRepository.withMutationsForTesting(
      api,
      session,
    );
  });

  tearDown(() => session.dispose());

  void expectCall(int index, ApiMethod method, String path, [Object? body]) {
    final call = transport.calls[index];
    expect(call.method, method);
    expect(call.uri.path, path);
    expect(call.uri.query, isEmpty);
    expect(call.headers['Authorization'], 'Bearer fixture-owner');
    if (body == null) {
      expect(call.body, isNull);
    } else {
      expect(call.headers['Content-Type'], 'application/json; charset=utf-8');
      expect(jsonDecode(call.body!), body);
    }
  }

  test('default adapter blocks both mutations before transport', () async {
    final intent = repo.prepareCreate(_offer);
    await expectLater(
      repo.create(intent),
      throwsA(isA<VoucherMutationsDisabled>()),
    );
    await expectLater(
      repo.cancel(_id, 'reason'),
      throwsA(isA<VoucherMutationsDisabled>()),
    );
    expect(transport.calls, isEmpty);
  });

  test(
    'create maps the body, coalesces concurrent submissions and reconciles completed intent',
    () async {
      final intent = enabled.prepareCreate(_offer.toUpperCase());
      final response = Completer<TransportResponse>();
      transport.respond = (_) => response.future;
      final first = enabled.create(intent);
      final concurrent = enabled.create(intent);
      expect(intent.offerId, _offer);
      expect(intent.requestId[14], '4');
      expect(enabled.prepareCreate(_offer).requestId, isNot(intent.requestId));
      response.complete(_json(_request(id: intent.requestId)));
      expect((await first).status, VoucherRequestStatus.pending);
      expect(await concurrent, await first);
      expect(transport.calls, hasLength(1));
      expectCall(0, ApiMethod.post, _path, {
        'requestId': intent.requestId,
        'offerId': _offer,
      });

      transport.respond = (_) =>
          _json(_request(id: intent.requestId, status: 2));
      expect(
        (await enabled.create(intent)).status,
        VoucherRequestStatus.approved,
      );
      expectCall(1, ApiMethod.get, '$_path/${intent.requestId}');
      expect(transport.calls, hasLength(2));
    },
  );

  test(
    'create timeout sends once and explicit retry reuses its original ID',
    () async {
      final timed = ApiVoucherRedemptionRepository.withMutationsForTesting(
        client(
          baseUrl: Uri.parse('https://example.invalid'),
          timeout: Duration.zero,
        ),
        session,
      );
      final intent = timed.prepareCreate(_offer);
      transport.respond = (_) => Completer<TransportResponse>().future;
      await expectLater(
        timed.create(intent),
        throwsA(_error(ApiError.timeout)),
      );
      expect(transport.calls, hasLength(1));

      transport.respond = (_) => const TransportResponse(404, []);
      await expectLater(
        timed.readRequest(intent.requestId),
        throwsA(_error(ApiError.notFound, status: 404)),
      );
      transport.respond = (_) => _json(_request(id: intent.requestId));
      expect((await timed.create(intent)).requestId, intent.requestId);
      final body = {'requestId': intent.requestId, 'offerId': _offer};
      expectCall(0, ApiMethod.post, _path, body);
      expectCall(1, ApiMethod.get, '$_path/${intent.requestId}');
      expectCall(2, ApiMethod.post, _path, body);
      expect(transport.calls, hasLength(3));
    },
  );

  test(
    'cancel maps reason, coalesces duplicate actions and validates status',
    () async {
      final response = Completer<TransportResponse>();
      transport.respond = (_) => response.future;
      final first = enabled.cancel(_id, '  synthetic reason  ');
      final duplicate = enabled.cancel(_id, 'synthetic reason');
      await expectLater(
        enabled.cancel(_id, 'different reason'),
        throwsA(_error(ApiError.conflict)),
      );
      response.complete(_json(_request(status: 4)));
      expect((await first).status, VoucherRequestStatus.cancelled);
      expect(await duplicate, await first);
      expect(transport.calls, hasLength(1));
      expectCall(0, ApiMethod.post, '$_path/$_id/cancel', {
        'reason': 'synthetic reason',
      });
      expect(await enabled.cancel(_id, 'synthetic reason'), await first);
      expectCall(1, ApiMethod.get, '$_path/$_id');
    },
  );

  test(
    'an owned detail read reconciles a create with an invalid response',
    () async {
      final intent = enabled.prepareCreate(_offer);
      transport.respond = (_) => _json(null);
      await expectLater(
        enabled.create(intent),
        throwsA(_error(ApiError.invalidResponse)),
      );
      transport.respond = (_) => _json(_request(id: intent.requestId));
      expect(
        (await enabled.readRequest(intent.requestId)).status,
        VoucherRequestStatus.pending,
      );
      expect(
        (await enabled.create(intent)).status,
        VoucherRequestStatus.pending,
      );
      expect(transport.calls.map((call) => call.method), [
        ApiMethod.post,
        ApiMethod.get,
        ApiMethod.get,
      ]);
    },
  );

  for (final status in VoucherRequestStatus.values) {
    test('detail decodes server request state ${status.name}', () async {
      transport.respond = (_) => _json(_request(status: status.index + 1));
      final request = await repo.readRequest(_id.toUpperCase());
      expect(request, (
        requestId: _id,
        offerId: _offer,
        ownerUserId: 'owner',
        ownerName: 'Synthetic Owner',
        costCoins: 10000,
        status: status,
        requestedAtUtc: DateTime.parse(_time),
        decidedAtUtc: status == VoucherRequestStatus.pending
            ? null
            : DateTime.parse(_time),
        decisionReason: status == VoucherRequestStatus.pending
            ? null
            : 'Synthetic decision',
      ));
      expectCall(0, ApiMethod.get, '$_path/$_id');
    });
  }

  for (final status in VoucherIssuanceStatus.values) {
    test('voucher decodes ${status.name} and limits secret exposure', () async {
      final dto = _voucher(status.index + 1);
      if (status == VoucherIssuanceStatus.expired) {
        dto['voucherCode'] = 'unexpected-secret';
        dto['qrPayload'] = 'unexpected-payload';
      }
      transport.respond = (_) => _json(dto);
      final voucher = await repo.readIssuedVoucher(_id);
      final reveal =
          status == VoucherIssuanceStatus.issued ||
          status == VoucherIssuanceStatus.used;
      expect(voucher.requestId, _id);
      expect(voucher.status, status);
      expect(voucher.referenceValueLkr, 100);
      expect(
        voucher.issuedAtUtc,
        dto['issuedAtUtc'] == null ? null : DateTime.parse(_time),
      );
      expect(
        voucher.expiresAtUtc,
        dto['expiresAtUtc'] == null ? null : DateTime.utc(2026, 12, 23, 10),
      );
      expect(
        voucher.usedAtUtc,
        status == VoucherIssuanceStatus.used ? DateTime.parse(_time) : null,
      );
      expect(voucher.voucherCode, reveal ? 'fixture-code' : null);
      expect(voucher.qrPayload, reveal ? 'fixture-payload' : null);
      expect(voucher.toString(), isNot(contains('fixture-')));
      expectCall(0, ApiMethod.get, '$_path/$_id/issued-voucher');
      await session.clear();
      expect(voucher.voucherCode, isNull);
      expect(voucher.qrPayload, isNull);
    });
  }

  test('HTTP errors preserve status without exposing backend bodies', () async {
    for (final (status, kind) in [
      (400, ApiError.rejected),
      (401, ApiError.unauthorized),
      (403, ApiError.forbidden),
      (404, ApiError.notFound),
      (503, ApiError.server),
    ]) {
      transport.respond = (_) =>
          _json({'error': 'fixture-private'}, status: status);
      await expectLater(
        repo.readRequest(_id),
        throwsA(_error(kind, status: status)),
      );
    }
    transport.respond = (_) => const TransportResponse(404, []);
    await expectLater(
      repo.readIssuedVoucher(_id),
      throwsA(_error(ApiError.notFound, status: 404)),
    );
    transport.respond = (_) => _json({'error': 'fixture-private'}, status: 409);
    await expectLater(
      enabled.cancel(_id, 'reason'),
      throwsA(_error(ApiError.conflict, status: 409)),
    );
    await expectLater(
      enabled.create(enabled.prepareCreate(_offer)),
      throwsA(_error(ApiError.conflict, status: 409)),
    );
    expect(session.state.status, SessionStatus.authenticated);
  });

  test(
    'network failure, unavailable service and detail timeout are typed',
    () async {
      transport.respond = (_) => throw const TransportFailure();
      await expectLater(
        repo.readRequest(_id),
        throwsA(_error(ApiError.network)),
      );
      final unavailable = ApiVoucherRedemptionRepository(client(), session);
      await expectLater(
        unavailable.readRequest(_id),
        throwsA(_error(ApiError.unavailable)),
      );
      expect(transport.calls, hasLength(1));

      final timed = ApiVoucherRedemptionRepository(
        client(
          baseUrl: Uri.parse('https://example.invalid'),
          timeout: Duration.zero,
        ),
        session,
      );
      transport.respond = (_) => Completer<TransportResponse>().future;
      await expectLater(
        timed.readIssuedVoucher(_id),
        throwsA(_error(ApiError.timeout)),
      );
    },
  );

  test(
    'malformed JSON, missing and invalid fields, mismatched owner and IDs fail safely',
    () async {
      transport.respond = (_) => TransportResponse(200, utf8.encode('{'));
      await expectLater(
        repo.readRequest(_id),
        throwsA(_error(ApiError.invalidResponse, status: 200)),
      );
      for (final dto in [
        null,
        [],
        _request()..remove('decisionReason'),
        _request()..['costCoins'] = '10000',
        _request()..['status'] = 'Pending',
        _request()..['status'] = 5,
        _request()..['requestedAtUtc'] = '2026-02-30T10:00:00Z',
        _request()..['ownerUserId'] = 'other-owner',
        _request(id: _offer),
      ]) {
        transport.respond = (_) => _json(dto);
        await expectLater(
          repo.readRequest(_id),
          throwsA(_error(ApiError.invalidResponse)),
        );
      }
      for (final dto in [
        _voucher(3)..remove('sampleImageReference'),
        _voucher(3)..['voucherCode'] = null,
        _voucher(3)..['qrPayload'] = ' ',
        _voucher(3)..['status'] = 6,
        _voucher(3)..['requestId'] = _offer,
      ]) {
        transport.respond = (_) => _json(dto);
        await expectLater(
          repo.readIssuedVoucher(_id),
          throwsA(_error(ApiError.invalidResponse)),
        );
      }
      transport.respond = (_) => _json(_request());
      await expectLater(
        enabled.cancel(_id, 'reason'),
        throwsA(_error(ApiError.invalidResponse)),
      );
    },
  );

  test('invalid IDs and blank cancel reasons never reach transport', () async {
    expect(() => enabled.prepareCreate('not-an-id'), throwsArgumentError);
    await expectLater(repo.readRequest('../requests'), throwsArgumentError);
    await expectLater(
      repo.readIssuedVoucher('00000000-0000-0000-0000-000000000000'),
      throwsArgumentError,
    );
    await expectLater(enabled.cancel(_id, '  '), throwsArgumentError);
    expect(transport.calls, isEmpty);
  });

  test(
    'account switch discards in-flight results and rejects old intents',
    () async {
      final read = Completer<TransportResponse>();
      final post = Completer<TransportResponse>();
      transport.respond = (request) =>
          request.method == ApiMethod.get ? read.future : post.future;
      final intent = enabled.prepareCreate(_offer);
      final pendingRead = expectLater(
        repo.readIssuedVoucher(_id),
        throwsA(_error(ApiError.unauthorized)),
      );
      final pendingPost = expectLater(
        enabled.create(intent),
        throwsA(_error(ApiError.unauthorized)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(transport.calls, hasLength(2));

      await signIn('other-owner');
      read.complete(_json(_voucher(3)));
      post.complete(_json(_request(id: intent.requestId)));
      await pendingRead;
      await pendingPost;

      final otherRepo = ApiVoucherRedemptionRepository.withMutationsForTesting(
        api,
        session,
      );
      await expectLater(
        otherRepo.create(intent),
        throwsA(_error(ApiError.unauthorized)),
      );
      await expectLater(
        repo.readRequest(_id),
        throwsA(_error(ApiError.unauthorized)),
      );
      expect(transport.calls, hasLength(2));

      transport.respond = (_) =>
          _json(_request()..['ownerUserId'] = 'other-owner');
      expect((await otherRepo.readRequest(_id)).ownerUserId, 'other-owner');
      expect(
        transport.calls.last.headers['Authorization'],
        'Bearer fixture-other-owner',
      );
    },
  );

  test(
    'sign-out and same-user sign-in invalidate the original scope',
    () async {
      final response = Completer<TransportResponse>();
      transport.respond = (_) => response.future;
      final result = expectLater(
        repo.readRequest(_id),
        throwsA(_error(ApiError.unauthorized)),
      );
      await session.clear();
      final signedOut = ApiVoucherRedemptionRepository(api, session);
      await expectLater(
        signedOut.readRequest(_id),
        throwsA(_error(ApiError.unauthorized)),
      );
      await signIn('owner');
      response.complete(_json(_request()));
      await result;
      await expectLater(
        repo.readRequest(_id),
        throwsA(_error(ApiError.unauthorized)),
      );
      expect(transport.calls, hasLength(1));
    },
  );
}
