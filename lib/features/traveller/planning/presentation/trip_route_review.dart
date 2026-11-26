import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/traveller/planning/data/trip_plans_api.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_plan.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_route_preview.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/trip_plan_widgets.dart';

class TripRouteReview extends StatefulWidget {
  const TripRouteReview({super.key, required this.plan, required this.api});

  final TripPlan plan;
  final TripPlansApi api;

  @override
  State<TripRouteReview> createState() => _TripRouteReviewState();
}

class _TripRouteReviewState extends State<TripRouteReview> {
  late Future<TripRoutePreview> _preview = widget.api.previewRoute(widget.plan);

  @override
  Widget build(BuildContext context) => TripContent(
    title: 'Route review',
    children: [
      Text(widget.plan.information.name),
      if (TripRoutePreview.supportsStops(widget.plan.stops))
        FutureBuilder<TripRoutePreview>(
          future: _preview,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const WayhunterLoadingView(label: 'Calculating route');
            }
            if (snapshot.error case ApiException(statusCode: 429)) {
              return const WayhunterUnavailableView(
                title: 'Daily route preview limit reached',
                message: 'Try again another day.',
              );
            }
            if (snapshot.hasError) {
              return WayhunterErrorView(
                title: 'Route estimate unavailable',
                message: switch (snapshot.error) {
                  ApiException(kind: ApiError.timeout || ApiError.network) =>
                    'Check your connection and try again.',
                  ApiException(
                    kind: ApiError.unauthorized || ApiError.forbidden,
                  ) =>
                    'Your account cannot access route review.',
                  ApiException(kind: ApiError.invalidResponse) ||
                  ApiException(
                    statusCode: 502,
                  ) => 'The route service returned an invalid estimate.',
                  _ => 'The route service could not calculate an estimate.',
                },
                onRetry: () {
                  final preview = widget.api.previewRoute(widget.plan);
                  setState(() {
                    _preview = preview;
                  });
                },
              );
            }
            final result = snapshot.requireData;
            return WayhunterSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Distance · ${result.distanceKm.toStringAsFixed(1)} km'),
                  Text(
                    'Estimated travel time · ${result.durationMinutes.toStringAsFixed(1)} min',
                  ),
                  Text(
                    result.provider == 'GoogleRoutes'
                        ? 'Google Routes'
                        : result.provider,
                  ),
                  const Text('Estimate excludes live traffic.'),
                ],
              ),
            );
          },
        )
      else
        const WayhunterUnavailableView(
          title: 'Route estimate needs saved map locations',
          message: 'Save 2 to 27 stops with a map location on each.',
        ),
      for (final (index, stop) in widget.plan.stops.indexed)
        Text('${index + 1}. ${stop.name}'),
    ],
  );
}
