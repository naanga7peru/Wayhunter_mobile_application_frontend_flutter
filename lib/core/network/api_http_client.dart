import 'package:http/http.dart' as http;
import 'package:wayhunter_mobile/core/network/local_https_client_stub.dart'
    if (dart.library.io) 'package:wayhunter_mobile/core/network/local_https_client_io.dart';

http.Client createApiHttpClient({
  required bool isDebug,
  required String environment,
  required Uri? apiBaseUrl,
  required String certificateDerBase64,
}) {
  if (isDebug &&
      environment == 'development' &&
      apiBaseUrl != null &&
      apiBaseUrl.scheme == 'https' &&
      apiBaseUrl.origin == 'https://localhost:7056') {
    return createLocalHttpsClient(certificateDerBase64);
  }
  return http.Client();
}
