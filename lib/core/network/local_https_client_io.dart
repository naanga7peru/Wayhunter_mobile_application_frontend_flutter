import 'dart:convert';
import 'dart:io';

import 'package:http/io_client.dart';

IOClient createLocalHttpsClient(String certificateDerBase64) {
  const setting = 'WAYHUNTER_LOCAL_HTTPS_CERT_DER_BASE64';
  if (certificateDerBase64.isEmpty) {
    throw StateError('$setting is required for local debug HTTPS.');
  }

  final context = SecurityContext(withTrustedRoots: true);
  try {
    final certificate = base64Decode(certificateDerBase64);
    // Require one DER sequence before the TLS parser validates its X.509 data.
    if (!_isSingleDerSequence(certificate)) throw const FormatException();
    // Android's TLS loader expects PEM. Armor the same DER bytes in memory.
    final pemBody = base64Encode(
      certificate,
    ).replaceAllMapped(RegExp('.{1,64}'), (line) => '${line[0]}\n');
    context.setTrustedCertificatesBytes(
      Platform.isIOS
          ? certificate
          : ascii.encode(
              '-----BEGIN CERTIFICATE-----\n'
              '$pemBody-----END CERTIFICATE-----\n',
            ),
    );
  } on FormatException {
    throw StateError('$setting must contain one base64 DER certificate.');
  } on TlsException {
    throw StateError('$setting must contain one base64 DER certificate.');
  }
  return IOClient(HttpClient(context: context));
}

bool _isSingleDerSequence(List<int> bytes) {
  if (bytes.length < 2 || bytes.first != 0x30) return false;
  final firstLength = bytes[1];
  if (firstLength < 0x80) return bytes.length == 2 + firstLength;

  final lengthBytes = firstLength & 0x7f;
  if (lengthBytes == 0 || lengthBytes > 4 || bytes.length < 2 + lengthBytes) {
    return false;
  }
  var contentLength = 0;
  for (var index = 2; index < 2 + lengthBytes; index++) {
    contentLength = (contentLength << 8) | bytes[index];
  }
  return bytes[2] != 0 &&
      contentLength >= 0x80 &&
      bytes.length == 2 + lengthBytes + contentLength;
}
