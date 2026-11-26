import 'package:wayhunter_mobile/core/network/api_client.dart';

bool isApiGuid(String value) =>
    value.length == 36 &&
    _guid.hasMatch(value) &&
    value != '00000000-0000-0000-0000-000000000000';

final _guid = RegExp(
  r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final _utc = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|\+00:00)$',
);

DateTime decodeApiUtc(String value) {
  if (_utc.hasMatch(value)) {
    final date = DateTime.tryParse(value);
    if (date != null &&
        date.year > 0 &&
        date.toIso8601String().substring(0, 19) == value.substring(0, 19)) {
      return date;
    }
  }
  throw const ApiException(ApiError.invalidResponse);
}
