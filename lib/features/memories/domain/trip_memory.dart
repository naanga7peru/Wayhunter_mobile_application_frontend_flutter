import 'package:wayhunter_mobile/core/network/api_client.dart';

enum TripMemoryVisibility {
  private(0, 'Private'),
  public(1, 'Public');

  const TripMemoryVisibility(this.wireValue, this.label);
  final int wireValue;
  final String label;

  static TripMemoryVisibility? fromWire(Object? value) => switch (value) {
    0 => TripMemoryVisibility.private,
    1 => TripMemoryVisibility.public,
    _ => null,
  };
}

class TripMemory {
  const TripMemory({
    required this.id,
    required this.tripPlanId,
    required this.tripStopId,
    required this.caption,
    required this.visibility,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.media,
  });

  final String id;
  final String tripPlanId;
  final String? tripStopId;
  final String caption;
  final TripMemoryVisibility visibility;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final TripMemoryMediaMetadata? media;

  factory TripMemory.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const ApiException(ApiError.invalidResponse);
    }
    final id = value['memoryId'];
    final tripId = value['tripPlanId'];
    final stopId = value['tripStopId'];
    final caption = value['caption'];
    final visibility = TripMemoryVisibility.fromWire(value['visibility']);
    final created = _date(value['createdAtUtc']);
    final updated = _date(value['updatedAtUtc']);
    final mediaRaw = value['media'];
    if (id is! String ||
        !isMemoryGuid(id) ||
        tripId is! String ||
        !isMemoryGuid(tripId) ||
        (stopId != null && (stopId is! String || !isMemoryGuid(stopId))) ||
        caption is! String ||
        visibility == null ||
        created == null ||
        updated == null ||
        (mediaRaw != null && mediaRaw is! Map<String, Object?>)) {
      throw const ApiException(ApiError.invalidResponse);
    }
    final media = mediaRaw == null
        ? null
        : TripMemoryMediaMetadata.fromJson(mediaRaw);
    return TripMemory(
      id: id,
      tripPlanId: tripId,
      tripStopId: stopId as String?,
      caption: caption,
      visibility: visibility,
      createdAtUtc: created,
      updatedAtUtc: updated,
      media: media,
    );
  }
}

class TripMemoryMediaMetadata {
  const TripMemoryMediaMetadata({
    required this.contentType,
    required this.contentLength,
  });
  final String contentType;
  final int contentLength;

  factory TripMemoryMediaMetadata.fromJson(Object? value) {
    if (value is! Map<String, Object?> ||
        value['contentType'] is! String ||
        value['contentLength'] is! int ||
        (value['contentLength'] as int) <= 0) {
      throw const ApiException(ApiError.invalidResponse);
    }
    return TripMemoryMediaMetadata(
      contentType: value['contentType'] as String,
      contentLength: value['contentLength'] as int,
    );
  }
}

bool isMemoryGuid(String value) =>
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value) &&
    value.replaceAll('-', '').split('').any((character) => character != '0');

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
