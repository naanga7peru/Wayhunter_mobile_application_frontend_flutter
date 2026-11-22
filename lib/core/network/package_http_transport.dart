import 'package:http/http.dart' as http;
import 'package:wayhunter_mobile/core/network/api_client.dart';

class PackageHttpTransport implements HttpTransport {
  PackageHttpTransport(this._client);

  final http.Client _client;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    final outgoing =
        http.Request(request.method.name.toUpperCase(), request.uri)
          ..followRedirects = false
          ..headers.addAll(request.headers);
    if (request.body case final body?) {
      outgoing.body = body;
    }
    try {
      final response = await http.Response.fromStream(
        await _client.send(outgoing),
      );
      return TransportResponse(response.statusCode, response.bodyBytes);
    } on http.ClientException {
      throw const TransportFailure();
    }
  }
}
