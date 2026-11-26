import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayhunter_mobile/core/network/api_http_client.dart';
import 'package:wayhunter_mobile/core/network/local_https_client_stub.dart'
    as unsupported_platform;

void main() {
  final localOrigin = Uri.parse('https://localhost:7056');
  const supportsDartIo = bool.fromEnvironment('dart.library.io');
  final unsupportedLocalHttps = isA<UnsupportedError>().having(
    (error) => error.message,
    'message',
    contains('Local debug HTTPS certificate trust requires'),
  );

  test('unsupported local HTTPS fails before creating a standard client', () {
    expect(
      () => http.runWithClient(
        () => unsupported_platform.createLocalHttpsClient(''),
        () => throw StateError('The standard client must not be used.'),
      ),
      throwsA(unsupportedLocalHttps),
    );
  });

  test('only the explicit local debug configuration replaces the client', () {
    final stockClient = MockClient((_) async => http.Response('', 200));
    addTearDown(stockClient.close);

    for (final (debug, environment, apiBaseUrl) in <(bool, String, Uri?)>[
      (false, 'development', localOrigin),
      (true, 'production', localOrigin),
      (true, 'staging', localOrigin),
      (true, '', localOrigin),
      (true, 'unknown', localOrigin),
      (true, 'development', null),
      (true, 'development', Uri.parse('http://localhost:7056')),
      (true, 'development', Uri.parse('https://localhost')),
      (true, 'development', Uri.parse('https://localhost:7057')),
      (true, 'development', Uri.parse('https://127.0.0.1:7056')),
      (true, 'development', Uri.parse('https://10.0.2.2:7056')),
      (true, 'development', Uri.parse('https://localhost.example.com:7056')),
    ]) {
      final client = http.runWithClient(
        () => createApiHttpClient(
          isDebug: debug,
          environment: environment,
          apiBaseUrl: apiBaseUrl,
          certificateDerBase64: 'deliberately invalid',
        ),
        () => stockClient,
      );
      expect(
        client,
        same(stockClient),
        reason: '$debug $environment $apiBaseUrl',
      );
    }
  });

  test('unusable local debug HTTPS configuration fails closed', () {
    final expectedError = supportsDartIo
        ? isStateError.having(
            (error) => error.message,
            'message',
            startsWith('WAYHUNTER_LOCAL_HTTPS_CERT_DER_BASE64'),
          )
        : unsupportedLocalHttps;
    for (final value in [
      '',
      'not base64!',
      base64Encode(utf8.encode('-----BEGIN CERTIFICATE-----')),
      base64Encode([0x30, 0x01, 0x00, 0x00]), // Trailing bytes.
      base64Encode([0x30, 0x00]), // A DER sequence with no certificate.
    ]) {
      expect(
        () => http.runWithClient(
          () => createApiHttpClient(
            isDebug: true,
            environment: 'development',
            apiBaseUrl: localOrigin,
            certificateDerBase64: value,
          ),
          () => throw StateError('The standard client must not be used.'),
        ),
        throwsA(expectedError),
      );
    }
  });
}
