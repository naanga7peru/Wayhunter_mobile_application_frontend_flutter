import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/network/api_dto.dart';
import 'package:wayhunter_mobile/core/network/session_api.dart';
import 'package:wayhunter_mobile/features/hunter/domain/hunter_history.dart';
import 'package:wayhunter_mobile/shared/domain/models/coordinates.dart';

class ApiHunterReader implements HunterHistory {
  const ApiHunterReader(this._api);

  final SessionApi _api;
  static const _base = ['api', 'mobile', 'hunter'];
  static const _invalid = ApiException(ApiError.invalidResponse);

  Future<List<ApprovedHunterPlace>> readPlaces() async {
    final value = await _api.request(ApiMethod.get, [..._base, 'places']);
    if (value is! List<Object?>) throw _invalid;
    return List.unmodifiable(value.map(_place));
  }

  @override
  Future<List<HuntSummary>> load() async {
    final value = await _api.request(ApiMethod.get, [..._base, 'submissions']);
    if (value is! List<Object?>) throw _invalid;
    return List.unmodifiable(
      value.map((entry) {
        if (entry case {'submissionId': final String id} when isApiGuid(id)) {
          return _summary(entry, id);
        }
        throw _invalid;
      }),
    );
  }

  Future<HuntSummary> readStatus(String id) async {
    if (!isApiGuid(id)) throw const ApiException(ApiError.notFound);
    return _summary(
      await _api.request(ApiMethod.get, [..._base, 'submissions', id]),
      id,
    );
  }

  static ApprovedHunterPlace _place(Object? value) {
    if (value
        case {
          'submissionId': final String id,
          'placeName': final String name,
          'district': final String district,
          'latitude': final num latitude,
          'longitude': final num longitude,
          'approvedAtUtc': final String approvedAt,
        }
        when isApiGuid(id) &&
            name.trim().isNotEmpty &&
            district.trim().isNotEmpty &&
            validCoordinates(latitude, longitude)) {
      return (
        id: id,
        name: name,
        district: district,
        latitude: latitude,
        longitude: longitude,
        approvedAt: decodeApiUtc(approvedAt),
      );
    }
    throw _invalid;
  }

  static HuntSummary _summary(Object? value, String id) {
    if (value case {
      'placeName': final String name,
      'district': final String district,
      'status': final int status,
      'createdAtUtc': final String createdAt,
      'submittedAtUtc': final String? submittedAt,
    } when name.trim().isNotEmpty && district.trim().isNotEmpty) {
      return HuntSummary(
        id: id,
        name: name,
        district: district,
        status: switch (status) {
          0 => HuntStatus.draft,
          1 => HuntStatus.pending,
          2 => HuntStatus.held,
          3 => HuntStatus.approved,
          4 => HuntStatus.rejected,
          _ => throw _invalid,
        },
        createdAt: decodeApiUtc(createdAt),
        submittedAt: submittedAt == null ? null : decodeApiUtc(submittedAt),
      );
    }
    throw _invalid;
  }
}
