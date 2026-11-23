import 'package:wayhunter_mobile/core/network/api_client.dart';

enum HazardStatus {
  reported(1, 'Unverified'),
  verified(2, 'Verified'),
  resolved(3, 'Resolved'),
  expired(4, 'Expired'),
  unknown(-1, 'Unknown status');

  const HazardStatus(this.wireValue, this.label);
  final int wireValue;
  final String label;

  static HazardStatus fromWire(Object? value) {
    for (final status in HazardStatus.values) {
      if (status.wireValue == value) return status;
    }
    return HazardStatus.unknown;
  }
}

class HazardWarning {
  const HazardWarning({
    required this.id,
    required this.status,
    required this.verified,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.hasPhotoEvidence,
    required this.photoCapturedAtUtc,
    required this.reportedAtUtc,
    required this.expiresAtUtc,
    required this.verifiedAtUtc,
    required this.resolvedAtUtc,
  });

  final String id;
  final HazardStatus status;
  final bool verified;
  final double? latitude;
  final double? longitude;
  final String? description;
  final bool hasPhotoEvidence;
  final DateTime photoCapturedAtUtc;
  final DateTime reportedAtUtc;
  final DateTime expiresAtUtc;
  final DateTime? verifiedAtUtc;
  final DateTime? resolvedAtUtc;

  factory HazardWarning.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const ApiException(ApiError.invalidResponse);
    }
    final id = value['hazardId'];
    final status = value['status'];
    final verified = value['isVerified'];
    final photoEvidence = value['hasPhotoEvidence'];
    final capturedAt = _date(value['photoCapturedAtUtc']);
    final reportedAt = _date(value['reportedAtUtc']);
    final expiresAt = _date(value['expiresAtUtc']);
    if (id is! String ||
        !_isGuid(id) ||
        status is! int ||
        verified is! bool ||
        photoEvidence is! bool ||
        capturedAt == null ||
        reportedAt == null ||
        expiresAt == null) {
      throw const ApiException(ApiError.invalidResponse);
    }
    final mappedStatus = HazardStatus.fromWire(status);
    if ((mappedStatus == HazardStatus.verified) != verified &&
        mappedStatus != HazardStatus.unknown) {
      throw const ApiException(ApiError.invalidResponse);
    }
    final latitude = value['latitude'];
    final longitude = value['longitude'];
    final description = value['description'];
    final verifiedAt = _nullableDate(value['verifiedAtUtc']);
    final resolvedAt = _nullableDate(value['resolvedAtUtc']);
    if ((latitude != null && latitude is! num) ||
        (longitude != null && longitude is! num) ||
        (description != null && description is! String) ||
        (value['verifiedAtUtc'] != null && verifiedAt == null) ||
        (value['resolvedAtUtc'] != null && resolvedAt == null)) {
      throw const ApiException(ApiError.invalidResponse);
    }
    return HazardWarning(
      id: id,
      status: mappedStatus,
      verified: verified,
      latitude: (latitude as num?)?.toDouble(),
      longitude: (longitude as num?)?.toDouble(),
      description: description as String?,
      hasPhotoEvidence: photoEvidence,
      photoCapturedAtUtc: capturedAt,
      reportedAtUtc: reportedAt,
      expiresAtUtc: expiresAt,
      verifiedAtUtc: verifiedAt,
      resolvedAtUtc: resolvedAt,
    );
  }
}

bool _isGuid(String value) =>
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value) &&
    value.replaceAll('-', '').split('').any((character) => character != '0');

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
DateTime? _nullableDate(Object? value) => value == null ? null : _date(value);
