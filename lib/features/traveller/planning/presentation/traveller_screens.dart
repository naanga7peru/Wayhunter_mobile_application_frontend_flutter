import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/data/trip_sessions_api.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/domain/trip_session.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/presentation/active_trip_screen.dart';
import 'package:wayhunter_mobile/features/friends/presentation/friends_screen.dart';
import 'package:wayhunter_mobile/features/traveller/planning/data/trip_plans_api.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_plan.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/trip_editor.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/trip_plan_widgets.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

class TravellerHome extends StatelessWidget {
  const TravellerHome({super.key});

  @override
  Widget build(BuildContext context) => TripContent(
    title: 'Traveller',
    children: [
      WayhunterSurfaceCard(
        child: WayhunterButton.primary(
          label: 'Create new trip',
          onPressed: () =>
              Navigator.of(context).pushNamed<void>(createTripRoute),
        ),
      ),
      WayhunterSurfaceCard(
        child: WayhunterButton.secondary(
          label: 'My Plans',
          onPressed: () =>
              Navigator.of(context).pushNamed<void>(myTripPlansRoute),
        ),
      ),
    ],
  );
}

class MyTripPlans extends StatefulWidget {
  const MyTripPlans({super.key, required this.api});
  final TripPlansApi api;

  @override
  State<MyTripPlans> createState() => _MyTripPlansState();
}

class _MyTripPlansState extends State<MyTripPlans> {
  late Future<List<TripPlan>> _plans = widget.api.list();

  void _load() {
    final plans = widget.api.list();
    setState(() {
      _plans = plans;
    });
  }

  Future<void> _open(AppDestination destination) async {
    await destination.open(context);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => TripRead(
    future: _plans,
    onRetry: _load,
    content: (plans) => TripContent(
      title: 'My Plans',
      children: [
        if (plans.isEmpty)
          const WayhunterEmptyView(
            title: 'No saved trips',
            message: 'Create a trip to start planning your stops.',
          ),
        for (final plan in plans)
          WayhunterSurfaceCard(
            onTap: () => _open(AppDestination.tripPlan(TripPlanRef(plan.id))),
            child: TripSummary(info: plan.information),
          ),
        WayhunterButton.primary(
          label: 'Create new trip',
          onPressed: () => _open(const AppDestination(createTripRoute)),
        ),
      ],
    ),
  );
}

class SavedTripDetails extends StatefulWidget {
  const SavedTripDetails({
    super.key,
    required this.api,
    required this.reference,
    required this.sessions,
  });

  final TripPlansApi api;
  final TripPlanRef reference;
  final TripSessionsApi sessions;

  @override
  State<SavedTripDetails> createState() => _SavedTripDetailsState();
}

class _SavedTripDetailsState extends State<SavedTripDetails> {
  final _stop = TextEditingController();
  late Future<TripPlan> _plan = widget.api.get(widget.reference.id);
  String? _error;
  bool _busy = false;
  bool _reloadRequired = false;
  bool _accessLost = false;
  String? _startError;

  @override
  void dispose() {
    _stop.dispose();
    super.dispose();
  }

  void _load() => setState(() {
    _error = null;
    _reloadRequired = false;
    _accessLost = false;
    _plan = widget.api.get(widget.reference.id);
  });

  Future<void> _mutate(Future<TripPlan?> Function() operation) async {
    if (_busy || _reloadRequired) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final plan = await operation();
      if (!mounted) return;
      if (plan == null) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _plan = SynchronousFuture(plan);
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = tripError(error);
        _accessLost = switch (error.kind) {
          ApiError.unauthorized ||
          ApiError.forbidden ||
          ApiError.notFound => true,
          _ => false,
        };
        _reloadRequired =
            error.kind == ApiError.conflict || tripMutationUncertain(error);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(TripPlan plan) async {
    await Navigator.of(context).push<TripPlan>(
      MaterialPageRoute(
        builder: (_) => WayhunterPageScaffold(
          appBar: AppBar(),
          body: TripEditor(api: widget.api, plan: plan),
        ),
      ),
    );
    if (mounted) _load();
  }

  void _add(TripPlan plan) {
    final name = _stop.text.trim();
    if (name.isEmpty || name.length > 200) {
      setState(() => _error = 'Enter a stop name up to 200 characters.');
      return;
    }
    FocusScope.of(context).unfocus();
    _mutate(() async {
      final updated = await widget.api.addStop(plan, name);
      if (mounted) _stop.clear();
      return updated;
    });
  }

  void _move(TripPlan plan, int from, int to) {
    final ids = plan.stops.map((stop) => stop.id).toList();
    ids.insert(to, ids.removeAt(from));
    _mutate(() => widget.api.reorder(plan, ids));
  }

  Future<void> _cancel(TripPlan plan) async {
    final confirmed = await showWayhunterConfirmation(
      context,
      title: 'Cancel trip?',
      message: 'Cancel this saved trip plan?',
      confirmLabel: 'Cancel trip',
      destructive: true,
    );
    if (confirmed && mounted) {
      await _mutate(() async {
        await widget.api.cancel(plan.id);
        return null;
      });
    }
  }

  Future<void> _openSession() async {
    if (_busy || _reloadRequired) return;
    setState(() {
      _busy = true;
      _startError = null;
    });
    TripSession? session;
    try {
      session =
          widget.sessions.known(widget.reference) ??
          await widget.sessions.start(widget.reference);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _startError = widget.sessions.startNeedsVerification(widget.reference)
              ? 'Start could not be confirmed. Recovery requires a session ID. Starting again is blocked.'
              : tripSessionError(error);
          _accessLost =
              error.kind == ApiError.unauthorized ||
              error.kind == ApiError.forbidden;
          if (_accessLost) _error = _startError;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (session == null || !mounted) return;
    await AppDestination.activeTrip(session.reference).open(context);
    if (mounted) setState(() {});
  }

  Widget _trip(TripPlan plan) {
    final knownSession = widget.sessions.known(widget.reference);
    final startBlocked = widget.sessions.startNeedsVerification(
      widget.reference,
    );
    final editable = !_busy && !_reloadRequired;
    return PopScope(
      canPop: !_busy,
      child: TripContent(
        title: 'Saved trip',
        children: [
          WayhunterSurfaceCard(child: TripSummary(info: plan.information)),
          WayhunterButton.primary(
            label: switch (knownSession?.status) {
              null => 'Start trip',
              TripSessionStatus.finished => 'View completed trip',
              _ => 'Open trip session',
            },
            onPressed: editable && !startBlocked ? _openSession : null,
          ),
          if (_startError case final message?)
            Semantics(liveRegion: true, child: Text(message))
          else if (startBlocked)
            const Text(
              'Start could not be confirmed. Recovery requires a session ID.',
            ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              WayhunterButton.secondary(
                label: 'Edit trip information',
                onPressed: editable && plan.hasRowVersion
                    ? () => _edit(plan)
                    : null,
              ),
              WayhunterButton.secondary(
                label: 'Add Friends',
                onPressed: editable
                    ? () => Navigator.of(context).pushNamed<void>(
                        tripFriendsRoute,
                        arguments: TripPlanRef(plan.id),
                      )
                    : null,
              ),
            ],
          ),
          if (!plan.hasRowVersion)
            const Text('Editing trip information requires a server version.'),
          const WayhunterHeader(title: 'Trip stops'),
          if (plan.stops.isEmpty) const Text('No stops added yet.'),
          for (final (i, stop) in plan.stops.indexed)
            TripStopTile(
              name: stop.name,
              index: i,
              moveUp: editable && i > 0 ? () => _move(plan, i, i - 1) : null,
              moveDown: editable && i + 1 < plan.stops.length
                  ? () => _move(plan, i, i + 1)
                  : null,
              remove: editable
                  ? () => _mutate(() => widget.api.removeStop(plan, stop.id))
                  : null,
            ),
          WayhunterTextField(
            label: 'Stop name',
            controller: _stop,
            enabled: editable,
          ),
          WayhunterButton.secondary(
            label: 'Add stop',
            onPressed: editable ? () => _add(plan) : null,
          ),
          if (_busy) const WayhunterLoadingView(label: 'Updating trip'),
          if (_error case final message?)
            Semantics(liveRegion: true, child: Text(message)),
          if (_reloadRequired)
            WayhunterButton.secondary(
              label: 'Reload saved plan',
              onPressed: _load,
            ),
          WayhunterButton.secondary(
            label: 'Cancel trip plan',
            onPressed: editable ? () => _cancel(plan) : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _accessLost
      ? WayhunterErrorView(
          title: 'Trip access unavailable',
          message: _error,
          onRetry: _load,
        )
      : TripRead(future: _plan, onRetry: _load, content: _trip);
}
