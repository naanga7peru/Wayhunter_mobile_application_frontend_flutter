import 'dart:convert';

import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/shared/domain/models/coordinates.dart';

bool isTripPlanId(String id) =>
    id != '00000000-0000-0000-0000-000000000000' &&
    RegExp(
      r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);

String tripDate(DateTime date) => date.toIso8601String().split('T').first;

DateTime? parseTripDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final date = DateTime.tryParse(value);
  return date != null && date.year > 0 && tripDate(date) == value ? date : null;
}

class TripInformation {
  const TripInformation({
    required this.name,
    required this.start,
    required this.end,
    required this.budget,
    required this.vehicle,
    required this.headcount,
  });

  final String name;
  final DateTime start;
  final DateTime end;
  final num budget;
  final String vehicle;
  final int headcount;

  Map<String, Object> toJson() => {
    'tripName': name,
    'startDate': tripDate(start),
    'endDate': tripDate(end),
    'budgetLkr': budget,
    'vehicleType': vehicle,
    'headcount': headcount,
  };
}

class TripStopDraft {
  const TripStopDraft(this.name, {this.placeId, this.latitude, this.longitude});

  final String name;
  final String? placeId;
  final num? latitude;
  final num? longitude;

  Map<String, Object> toJson() {
    final lat = latitude;
    final lng = longitude;
    final providerId = placeId;
    if (!validCoordinates(lat, lng) || (providerId?.length ?? 0) > 256) {
      throw const ApiException(ApiError.rejected);
    }
    return {
      'name': name,
      'placeId': ?providerId,
      if (lat != null && lng != null) ...{'latitude': lat, 'longitude': lng},
    };
  }
}

class TripStop {
  const TripStop({
    required this.id,
    required this.order,
    required this.name,
    this.placeId,
    this.latitude,
    this.longitude,
  });

  final String id;
  final int order;
  final String name;
  final String? placeId;
  final num? latitude;
  final num? longitude;

  factory TripStop.fromJson(Object? json) {
    if (json
        case {
          'stopId': final String id,
          'orderIndex': final int order,
          'name': final String name,
          'placeId': final String? placeId,
          'latitude': final num? latitude,
          'longitude': final num? longitude,
        }
        when isTripPlanId(id) &&
            order >= 0 &&
            name.trim().isNotEmpty &&
            (placeId?.length ?? 0) <= 256 &&
            validCoordinates(latitude, longitude)) {
      return TripStop(
        id: id,
        order: order,
        name: name,
        placeId: placeId,
        latitude: latitude,
        longitude: longitude,
      );
    }
    throw const ApiException(ApiError.invalidResponse);
  }
}

class TripPlan {
  const TripPlan({
    required this.id,
    required this.information,
    required this.stops,
    required this.rowVersion,
  });

  final String id;
  final TripInformation information;
  final List<TripStop> stops;
  final String rowVersion;

  bool get hasRowVersion => rowVersion.isNotEmpty;

  factory TripPlan.fromJson(Object? json) {
    if (json
        case {
          'tripPlanId': final String id,
          'tripName': final String name,
          'startDate': final String start,
          'endDate': final String end,
          'budgetLkr': final num budget,
          'vehicleType': final String vehicle,
          'headcount': final int headcount,
          'stops': final List<Object?> rawStops,
          'rowVersion': final String version,
        }
        when isTripPlanId(id) &&
            name.trim().isNotEmpty &&
            vehicle.trim().isNotEmpty &&
            budget.isFinite &&
            budget >= 0 &&
            headcount > 0) {
      final from = parseTripDate(start);
      final to = parseTripDate(end);
      if (from != null &&
          to != null &&
          !to.isBefore(from) &&
          _validVersion(version)) {
        final stops = rawStops.map(TripStop.fromJson).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        if (stops.map((stop) => stop.id.toLowerCase()).toSet().length ==
                stops.length &&
            stops.map((stop) => stop.order).toSet().length == stops.length) {
          return TripPlan(
            id: id,
            information: TripInformation(
              name: name,
              start: from,
              end: to,
              budget: budget,
              vehicle: vehicle,
              headcount: headcount,
            ),
            stops: List.unmodifiable(stops),
            rowVersion: version,
          );
        }
      }
    }
    throw const ApiException(ApiError.invalidResponse);
  }

  static bool _validVersion(String value) {
    if (value.isEmpty) return true;
    try {
      final bytes = base64Decode(value);
      return bytes.length == 8 && base64Encode(bytes) == value;
    } on FormatException {
      return false;
    }
  }
}
