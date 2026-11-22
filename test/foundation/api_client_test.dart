import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/core/auth/access_token_source.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';

class FakeTransport implements HttpTransport {
  FakeTransport(this.respond);

  final Future<TransportResponse> Function(TransportRequest) respond;
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) {
    requests.add(request);
    return respond(request);
  }
}

class FixedTokenSource implements AccessTokenSource {
  const FixedTokenSource(this.accessToken);
  @override
  final String? accessToken;
}

void main() {
  const path = ['test-resource', 'row#1'];
  final baseUrl = Uri.parse('https://example.test/root/');
  TypeMatcher<ApiException> error(ApiError kind, [int? status]) =>
      isA<ApiException>()
          .having((value) => value.kind, 'kind', kind)
          .having((value) => value.statusCode, 'status', status);

  test('encodes path, query and JSON and supports all four methods', () async {
    final transport = FakeTransport(
      (_) async => TransportResponse(200, utf8.encode('{"count":2}')),
    );
    final api = ApiClient(
      baseUrl: baseUrl,
      transport: transport,
      tokens: const FixedTokenSource('fixture-token'),
    );

    for (final method in ApiMethod.values) {
      expect(
        await api.request(
          method,
          path,
          query: {'q': 'a & b'},
          jsonBody: method == ApiMethod.put ? {'count': 2} : null,
          requiresSession: method == ApiMethod.put,
        ),
        {'count': 2},
      );
    }
    expect(
      transport.requests.map((request) => request.method),
      ApiMethod.values,
    );
    final put = transport.requests[2];
    expect(put.uri.pathSegments, ['root', ...path]);
    expect(put.uri.queryParameters, {'q': 'a & b'});
    expect(put.headers['Authorization'], 'Bearer fixture-token');
    expect(put.headers['Content-Type'], contains('application/json'));
    expect(jsonDecode(put.body!), {'count': 2});
    expect(transport.requests.first.headers, isNot(contains('Authorization')));
  });

  test(
    'rejects invalid configuration, unsafe paths and missing sessions before sending',
    () async {
      final transport = FakeTransport(
        (_) async => const TransportResponse(204, []),
      );
      ApiClient client(Uri? url) => ApiClient(
        baseUrl: url,
        transport: transport,
        tokens: const FixedTokenSource(null),
      );

      await expectLater(
        client(null).request(ApiMethod.get, path),
        throwsA(error(ApiError.unavailable)),
      );
      await expectLater(
        client(Uri.parse('http://example.test')).request(ApiMethod.get, path),
        throwsA(error(ApiError.unavailable)),
      );
      final api = client(baseUrl);
      for (final segment in ['..', 'https://other.test', '%2e%2e', 'a\\b']) {
        await expectLater(
          api.request(ApiMethod.get, [segment]),
          throwsArgumentError,
        );
      }
      await expectLater(
        api.request(ApiMethod.get, path, requiresSession: true),
        throwsA(error(ApiError.unauthorized)),
      );
      expect(transport.requests, isEmpty);
    },
  );

  for (final (status, kind) in [
    (401, ApiError.unauthorized),
    (403, ApiError.forbidden),
    (404, ApiError.notFound),
    (409, ApiError.conflict),
    (503, ApiError.server),
    (400, ApiError.rejected),
  ]) {
    test('maps HTTP $status without exposing response body', () async {
      final api = ApiClient(
        baseUrl: baseUrl,
        transport: FakeTransport(
          (_) async => TransportResponse(
            status,
            utf8.encode('internal diagnostic text'),
          ),
        ),
        tokens: const FixedTokenSource(null),
      );
      await expectLater(
        api.request(ApiMethod.get, path),
        throwsA(
          error(kind, status).having(
            (value) => value.toString(),
            'display text',
            isNot(contains('internal diagnostic text')),
          ),
        ),
      );
    });
  }

  test('handles empty and malformed success responses', () async {
    var response = const TransportResponse(204, []);
    final api = ApiClient(
      baseUrl: baseUrl,
      transport: FakeTransport((_) async => response),
      tokens: const FixedTokenSource(null),
    );
    expect(await api.request(ApiMethod.delete, path), isNull);
    response = const TransportResponse(200, [255]);
    await expectLater(
      api.request(ApiMethod.get, path),
      throwsA(error(ApiError.invalidResponse, 200)),
    );
  });

  test('maps network failures and request timeouts distinctly', () async {
    final pending = Completer<TransportResponse>();
    final source = FixedTokenSource(null);
    final api = ApiClient(
      baseUrl: baseUrl,
      transport: FakeTransport((_) => pending.future),
      tokens: source,
      timeout: Duration.zero,
    );
    await expectLater(
      api.request(ApiMethod.get, path),
      throwsA(error(ApiError.timeout)),
    );
    pending.complete(const TransportResponse(204, []));
    final offline = ApiClient(
      baseUrl: baseUrl,
      transport: FakeTransport((_) async => throw const TransportFailure()),
      tokens: source,
    );
    await expectLater(
      offline.request(ApiMethod.get, path),
      throwsA(error(ApiError.network)),
    );
  });
}
