import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/safety/data/trip_hazards_api.dart';
import 'package:wayhunter_mobile/features/safety/domain/hazard_warning.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/trip_plan_widgets.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

const tripSafetyRoute = 'traveller.activeTrip.safety';
const tripHazardDetailsRoute = 'traveller.activeTrip.safety.details';

class HazardDetailsArgs {
  const HazardDetailsArgs({required this.plan, required this.warning});
  final TripPlanRef plan;
  final HazardWarning warning;
}

String _safetyFailure(ApiException error) => switch (error.kind) {
  ApiError.unauthorized =>
    'Sign in again to view this trip safety information.',
  ApiError.forbidden => 'Your account is not permitted to view these warnings.',
  ApiError.notFound => 'This trip is not available.',
  ApiError.unavailable || ApiError.server =>
    'The hazard warning service is unavailable on this configuration.',
  ApiError.network || ApiError.timeout =>
    'Could not reach the hazard warning service. Check your connection.',
  ApiError.invalidResponse =>
    'The server returned malformed hazard information.',
  _ => 'Hazard warnings could not be loaded.',
};

class TripSafetyScreen extends StatefulWidget {
  const TripSafetyScreen({super.key, required this.plan, required this.api});

  final TripPlanRef plan;
  final TripHazardsApi api;

  @override
  State<TripSafetyScreen> createState() => _TripSafetyScreenState();
}

class _TripSafetyScreenState extends State<TripSafetyScreen> {
  late Future<List<HazardWarning>> _warnings;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _warnings = _load();
  }

  Future<List<HazardWarning>> _load() async {
    try {
      _loadError = null;
      return await widget.api.listForTrip(widget.plan.id);
    } catch (error) {
      _loadError = error;
      return const [];
    }
  }

  void _retry() => setState(() => _warnings = _load());

  @override
  Widget build(BuildContext context) => TripContent(
    title: 'Trip safety',
    children: [
      const Text(
        'Warnings are returned only when the planned route passes within 1 km. Active warning eligibility ends 24 hours after the server report time.',
      ),
      FutureBuilder<List<HazardWarning>>(
        future: _warnings,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const WayhunterLoadingView(label: 'Loading trip safety');
          }
          if (snapshot.hasError || _loadError != null) {
            final error = snapshot.error ?? _loadError;
            return WayhunterErrorView(
              title: 'Safety warnings unavailable',
              message: error is ApiException
                  ? _safetyFailure(error)
                  : 'Safety warnings could not be loaded.',
              onRetry: _retry,
            );
          }
          final warnings = snapshot.requireData;
          if (warnings.isEmpty) {
            return WayhunterUnavailableView(
              title: 'Route warnings cannot be confirmed',
              message:
                  'No eligible warning was returned. The backend response does not report whether route matching is configured, so this is not confirmation that the route has no hazards.',
              action: WayhunterButton.secondary(
                label: 'Retry',
                onPressed: _retry,
              ),
            );
          }
          return Column(
            children: [
              for (final warning in warnings)
                Card(
                  child: ListTile(
                    title: Text(
                      warning.description?.isNotEmpty == true
                          ? warning.description!
                          : 'Road hazard',
                    ),
                    subtitle: Text(
                      '${warning.status.label} · Photo captured ${warning.photoCapturedAtUtc.toLocal()}\nReported ${warning.reportedAtUtc.toLocal()} · Expires ${warning.expiresAtUtc.toLocal()}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pushNamed<void>(
                      tripHazardDetailsRoute,
                      arguments: HazardDetailsArgs(
                        plan: widget.plan,
                        warning: warning,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const WayhunterUnavailableView(
        title: 'Hazard reporting unavailable',
        message:
            'Reporting requires a verified live location, captured photo and private uploaded asset reference. This app configuration does not provide the required capture and upload services.',
      ),
    ],
  );
}

class TripHazardDetailsScreen extends StatelessWidget {
  const TripHazardDetailsScreen({super.key, required this.args});
  final HazardDetailsArgs args;

  @override
  Widget build(BuildContext context) {
    final warning = args.warning;
    return TripContent(
      title: 'Hazard details',
      children: [
        Text(
          warning.status.label,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          warning.description?.isNotEmpty == true
              ? warning.description!
              : 'No description supplied.',
        ),
        Text(
          'Photo evidence: ${warning.hasPhotoEvidence ? 'Available' : 'Not available'}',
        ),
        Text('Photo captured: ${warning.photoCapturedAtUtc.toLocal()}'),
        Text('Reported by server: ${warning.reportedAtUtc.toLocal()}'),
        Text('Warning expires: ${warning.expiresAtUtc.toLocal()}'),
        if (warning.verifiedAtUtc case final verified?)
          Text('Verified: ${verified.toLocal()}'),
        if (warning.resolvedAtUtc case final resolved?)
          Text('Resolved: ${resolved.toLocal()}'),
        if (warning.latitude != null && warning.longitude != null)
          const Text('Hazard location is supplied by the server.'),
        const Text(
          'The 24-hour warning window is based on the server report timestamp. Verification state is shown only as returned by the server.',
        ),
      ],
    );
  }
}
