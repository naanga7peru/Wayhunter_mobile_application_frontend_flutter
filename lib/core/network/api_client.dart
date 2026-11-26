import 'dart:async';
import 'dart:convert';

import 'package:wayhunter_mobile/core/auth/access_token_source.dart';

enum ApiMethod { get, post, put, delete }

enum ApiError {
  unavailable,
  timeout,
  network,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  server,
  rejected,
  invalidResponse,
}

class ApiException implements Exception {
  const ApiException(this.kind, {this.statusCode, this.retryAfterSeconds});

  final ApiError kind;
  final int? statusCode;
  final int? retryAfterSeconds;

  @override
  String toString() => 'ApiException(${kind.name}, status: $statusCode)';
}

class TransportRequest {
  const TransportRequest(this.method, this.uri, this.headers, this.body);

  final ApiMethod method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
}

class TransportResponse {
  const TransportResponse(this.statusCode, this.bodyBytes, {this.retryAfter});

  final int statusCode;
  final List<int> bodyBytes;
  final String? retryAfter;
}

class TransportFailure implements Exception {
  const TransportFailure();
}

abstract interface class HttpTransport {
  Future<TransportResponse> send(TransportRequest request);
}

class ApiClient {
  ApiClient({
    required Uri? baseUrl,
    required HttpTransport transport,
    required AccessTokenSource tokens,
    Duration timeout = const Duration(seconds: 15),
    void Function() Function()? captureUnauthorizedHandler,
  }) : _baseUrl = validatedBaseUrl(baseUrl),
       _transport = transport,
       _tokens = tokens,
       _timeout = timeout,
       _captureUnauthorizedHandler = captureUnauthorizedHandler;

  final Uri? _baseUrl;
  final HttpTransport _transport;
  final AccessTokenSource _tokens;
  final Duration _timeout;
  final void Function() Function()? _captureUnauthorizedHandler;

  /// Feature adapters supply exact path segments and decode the returned JSON.
  /// A null result represents an empty response or a JSON null.
  Future<Object?> request(
    ApiMethod method,
    List<String> path, {
    Map<String, String>? query,
    Object? jsonBody,
    bool requiresSession = false,
    String? ifMatch,
    int? expectedSuccessStatus,
  }) async {
    final baseUrl = _baseUrl;
    if (baseUrl == null) throw const ApiException(ApiError.unavailable);
    if (path.isEmpty || path.any(_invalidSegment)) {
      throw ArgumentError('Invalid API path segments.');
    }
    final uri = baseUrl.replace(
      pathSegments: [
        ...baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
        ...path,
      ],
      queryParameters: query,
    );
    final headers = <String, String>{'Accept': 'application/json'};
    if (ifMatch != null) {
      if (_strongEntityTag.stringMatch(ifMatch) != ifMatch) {
        throw ArgumentError('If-Match requires a single strong entity tag.');
      }
      headers['If-Match'] = ifMatch;
    }
    final body = jsonBody == null ? null : jsonEncode(jsonBody);
    if (body != null) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }
    void Function()? onUnauthorized;
    if (requiresSession) {
      final token = _tokens.accessToken;
      if (token == null) throw const ApiException(ApiError.unauthorized);
      headers['Authorization'] = 'Bearer $token';
      onUnauthorized = _captureUnauthorizedHandler?.call();
    }

    final TransportResponse response;
    try {
      response = await _transport
          .send(TransportRequest(method, uri, headers, body))
          .timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(ApiError.timeout);
    } on TransportFailure {
      throw const ApiException(ApiError.network);
    }

    final status = response.statusCode;
    if (status == 401) onUnauthorized?.call();
    if (status < 200 || status >= 300) {
      final kind = switch (status) {
        401 => ApiError.unauthorized,
        403 => ApiError.forbidden,
        404 => ApiError.notFound,
        409 => ApiError.conflict,
        >= 500 && < 600 => ApiError.server,
        _ => ApiError.rejected,
      };
      throw ApiException(
        kind,
        statusCode: status,
        retryAfterSeconds: status == 429
            ? _retryAfterSeconds(response.retryAfter)
            : null,
      );
    }
    if (expectedSuccessStatus != null && status != expectedSuccessStatus) {
      throw ApiException(ApiError.invalidResponse, statusCode: status);
    }
    if (response.bodyBytes.isEmpty || status == 204) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(ApiError.invalidResponse, statusCode: status);
    }
  }

  static Uri? validatedBaseUrl(Uri? url) {
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment ||
        url.pathSegments
            .where((segment) => segment.isNotEmpty)
            .any(_invalidSegment)) {
      return null;
    }
    return url;
  }

  static int? _retryAfterSeconds(String? header) {
    final value = header?.trim();
    if (value == null || !_delaySeconds.hasMatch(value)) return null;
    final seconds = int.tryParse(value);
    return seconds != null && seconds > 0 && seconds <= 0x7fffffff
        ? seconds
        : null;
  }

  static bool _invalidSegment(String segment) =>
      segment.isEmpty ||
      segment == '.' ||
      segment == '..' ||
      RegExp(r'[/\\%\x00-\x20\x7F]').hasMatch(segment);

  static final _strongEntityTag = RegExp(r'^"[\x21\x23-\x7e]*"$');
  static final _delaySeconds = RegExp(r'^[0-9]+$');
}
