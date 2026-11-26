import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_plan.dart';
import 'package:wayhunter_mobile/shared/domain/models/coordinates.dart';

class TripRoutePreview {
  const TripRoutePreview({
    required this.distanceKm,
    required this.durationMinutes,
    required this.provider,
  });

  final num distanceKm;
  final num durationMinutes;
  final String provider;

  static bool supportsStops(List<TripStop> stops) =>
      stops.length >= 2 &&
      stops.length <= 27 &&
      stops.every(
        (stop) =>
            stop.latitude != null &&
            validCoordinates(stop.latitude, stop.longitude),
      );

  factory TripRoutePreview.fromJson(Object? response) {
    if (response
        case {
          'routeGeometry': final List<Object?> geometry,
          'distanceKm': final num distance,
          'estimatedDurationMinutes': final num duration,
          'providerName': final String provider,
          'trafficAware': false,
        }
        when geometry.length >= 2 &&
            geometry.length <= 20000 &&
            geometry.every(_validPoint) &&
            distance.isFinite &&
            distance >= 0 &&
            duration.isFinite &&
            duration >= 0 &&
            provider.trim().isNotEmpty) {
      return TripRoutePreview(
        distanceKm: distance,
        durationMinutes: duration,
        provider: provider,
      );
    }
    throw const ApiException(ApiError.invalidResponse);
  }

  static bool _validPoint(Object? value) => switch (value) {
    {'latitude': final num latitude, 'longitude': final num longitude} =>
      validCoordinates(latitude, longitude),
    _ => false,
  };
}
