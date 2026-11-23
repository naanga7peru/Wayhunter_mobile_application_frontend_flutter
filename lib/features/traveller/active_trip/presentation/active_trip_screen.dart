import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/data/trip_sessions_api.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/domain/trip_session.dart';
import 'package:wayhunter_mobile/features/traveller/planning/data/trip_plans_api.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/trip_plan_widgets.dart';
import 'package:wayhunter_mobile/features/safety/presentation/safety_screens.dart';
import 'package:wayhunter_mobile/features/memories/presentation/memories_screens.dart';

String tripSessionError(ApiException error) => switch (error.kind) {
  ApiError.unauthorized =>
    'Your sign-in session expired or is no longer authorized.',
  ApiError.forbidden => 'Your account cannot access this trip session.',
  ApiError.notFound =>
    'This session could not be recovered. It may have ended or is no longer available.',
  ApiError.unavailable =>
    'Trip sessions are unavailable on this app configuration.',
  ApiError.server =>
    'The trip service is unavailable. Try recovering when it is back online.',
  ApiError.conflict =>
    'The trip session changed. Recover its current status before continuing.',
  ApiError.network || ApiError.timeout =>
    'Could not reach the trip service. Check your connection.',
  ApiError.invalidResponse => 'The server returned an invalid trip session.',
  _ => 'Wayhunter could not accept this trip session request.',
};

class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({
    super.key,
    required this.reference,
    required this.plans,
    required this.sessions,
  });

  final ActiveTripArgs reference;
  final TripPlansApi plans;
  final TripSessionsApi sessions;

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  TripSession? _session;
  String? _tripName;
  String? _notice;
  ApiException? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _recover(allowConfirmedFinish: true);
  }

  Future<void> _recover({bool allowConfirmedFinish = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      // Recover also permits active members on the server. This owner-only
      // screen first checks the saved plan through the owner-only M2 read.
      final plan = await widget.plans.get(widget.reference.plan.id);
      if (!mounted) return;
      final known = widget.sessions.known(widget.reference.plan);
      final result =
          allowConfirmedFinish &&
              known?.status == TripSessionStatus.finished &&
              known!.reference.session.id.toLowerCase() ==
                  widget.reference.session.id.toLowerCase()
          ? known
          : await widget.sessions.recover(widget.reference);
      if (!mounted) return;
      setState(() {
        _tripName = plan.information.name;
        _session = result;
      });
    } on ApiException catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(ApiException error) {
    if (!mounted) return;
    setState(() {
      _session = null;
      _error = error;
    });
  }

  Future<void> _change(TripSessionAction action) async {
    final current = _session;
    if (_busy || current == null || !action.allows(current.status)) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final result = await widget.sessions.change(current.reference, action);
      if (mounted) setState(() => _session = result);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (!TripSessionsApi.needsReconciliation(error)) {
        _showError(error);
        return;
      }
      setState(() {
        _session = null;
        _notice = 'The action was not confirmed. Checking the server status.';
      });
      try {
        final recovered = await widget.sessions.recover(current.reference);
        if (mounted) {
          setState(() {
            _session = recovered;
            _notice = 'Current session status recovered from the server.';
          });
        }
      } on ApiException catch (recoveryError) {
        _showError(recoveryError);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final error = _error;
    return PopScope(
      canPop: !_busy,
      child: switch ((session, error)) {
        (_, final ApiException failure) => WayhunterErrorView(
          title: 'Trip session unavailable',
          message: tripSessionError(failure),
          onRetry: _recover,
        ),
        (final TripSession confirmed, _) => _sessionContent(confirmed),
        _ => const WayhunterLoadingView(label: 'Checking trip session'),
      },
    );
  }

  Widget _sessionContent(TripSession session) {
    final completed = session.status == TripSessionStatus.finished;
    return TripContent(
      title: completed ? 'Completed trip' : 'Active trip',
      children: [
        WayhunterSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_tripName!, style: Theme.of(context).textTheme.titleLarge),
              WayhunterStatusIndicator(
                label: session.status.label,
                tone: completed
                    ? WayhunterStatusTone.success
                    : WayhunterStatusTone.info,
              ),
              Text('Started ${session.startedAtUtc.toIso8601String()}'),
              if (session.finishedAtUtc case final finished?)
                Text('Finished ${finished.toIso8601String()}'),
            ],
          ),
        ),
        if (_notice case final message?)
          Semantics(liveRegion: true, child: Text(message)),
        if (_busy) const WayhunterLoadingView(label: 'Checking trip session'),
        WayhunterButton.secondary(
          label: 'Trip memories',
          onPressed: _busy
              ? null
              : () => Navigator.of(context).pushNamed<void>(
                  tripMemoriesRoute,
                  arguments: session.reference.plan,
                ),
        ),
        if (completed)
          WayhunterButton.primary(
            label: 'Back to saved trip',
            onPressed: () => Navigator.of(context).pop(),
          )
        else ...[
          WayhunterButton.secondary(
            label: 'Trip safety',
            onPressed: () => Navigator.of(context).pushNamed<void>(
              tripSafetyRoute,
              arguments: widget.reference.plan,
            ),
          ),
          for (final action in TripSessionAction.values)
            if (action.allows(session.status))
              WayhunterButton.primary(
                label: action.label,
                onPressed: _busy ? null : () => _change(action),
              ),
          WayhunterButton.secondary(
            label: 'Recover session',
            onPressed: _busy ? null : _recover,
          ),
        ],
      ],
    );
  }
}
