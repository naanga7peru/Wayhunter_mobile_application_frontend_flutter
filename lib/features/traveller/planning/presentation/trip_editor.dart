import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/friends/presentation/friends_screen.dart';
import 'package:wayhunter_mobile/features/traveller/planning/data/trip_plans_api.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_plan.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/traveller_location_picker.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/trip_plan_widgets.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

const myTripPlansRoute = 'traveller.myPlans';
const createTripRoute = 'traveller.createTrip';

enum _Step { information, stops, review }

class TripEditor extends StatefulWidget {
  const TripEditor({super.key, required this.api, this.plan});

  final TripPlansApi api;
  final TripPlan? plan;

  @override
  State<TripEditor> createState() => _TripEditorState();
}

class _TripEditorState extends State<TripEditor> {
  final _form = GlobalKey<FormState>();
  final _stop = TextEditingController();
  final _stops = <({String name, LatLng? location})>[];
  late final _name = TextEditingController(text: widget.plan?.information.name);
  late final _vehicle = TextEditingController(
    text: widget.plan?.information.vehicle,
  );
  late final _budget = TextEditingController(
    text: widget.plan?.information.budget.toString(),
  );
  late final _headcount = TextEditingController(
    text: widget.plan?.information.headcount.toString(),
  );
  late final _start = TextEditingController(
    text: widget.plan == null ? null : tripDate(widget.plan!.information.start),
  );
  late final _end = TextEditingController(
    text: widget.plan == null ? null : tripDate(widget.plan!.information.end),
  );
  _Step _step = _Step.information;
  TripInformation? _info;
  bool _busy = false;
  bool _reloadRequired = false;
  bool _uncertainCreate = false;
  String? _error;
  String? _stopError;
  LatLng? _stopLocation;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _vehicle,
      _budget,
      _headcount,
      _start,
      _end,
      _stop,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _continue() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _info = TripInformation(
        name: _name.text.trim(),
        start: parseTripDate(_start.text.trim())!,
        end: parseTripDate(_end.text.trim())!,
        budget: num.parse(_budget.text.trim()),
        vehicle: _vehicle.text.trim(),
        headcount: int.parse(_headcount.text.trim()),
      );
      _step = widget.plan == null ? _Step.stops : _Step.review;
    });
  }

  void _addStop() {
    final name = _stop.text.trim();
    setState(() {
      _stopError = switch (name) {
        _ when name.isEmpty || name.length > 200 =>
          'Enter a stop name up to 200 characters.',
        _ when _stops.length >= 100 =>
          'A new trip can include up to 100 stops.',
        _
            when _stops.any(
              (stop) => stop.name.toUpperCase() == name.toUpperCase(),
            ) =>
          'This stop is already in the trip.',
        _ => null,
      };
      if (_stopError == null) {
        _stops.add((name: name, location: _stopLocation));
        _stop.clear();
        _stopLocation = null;
      }
    });
  }

  Future<void> _pickStopLocation() async {
    FocusScope.of(context).unfocus();
    final services = FoundationServices.of(context);
    final location = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => TravellerLocationPicker(
          maps: services.maps,
          permissions: services.permissions,
          location: services.location,
          initialSelection: _stopLocation,
        ),
      ),
    );
    if (!mounted || location == null) return;
    setState(() => _stopLocation = location);
  }

  void _moveStop(int from, int to) =>
      setState(() => _stops.insert(to, _stops.removeAt(from)));

  Future<void> _save() async {
    if (_busy || _reloadRequired || _uncertainCreate) return;
    final plan = widget.plan;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = plan == null
          ? await widget.api.create(
              _info!,
              _stops.map((stop) => stop.name).toList(),
            )
          : await widget.api.update(plan, _info!);
      if (!mounted) return;
      if (plan == null) {
        Navigator.of(context).pushReplacementNamed<void, void>(
          AppRoutes.tripPlan,
          arguments: TripPlanRef(saved.id),
        );
      } else {
        Navigator.of(context).pop(saved);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = tripError(error);
        _uncertainCreate = plan == null && tripMutationUncertain(error);
        _reloadRequired =
            plan != null &&
            (error.kind == ApiError.conflict || tripMutationUncertain(error));
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRetry() async {
    final confirmed = await showWayhunterConfirmation(
      context,
      title: 'Create another request?',
      message:
          'Continue only if the trip is missing from My Plans. The previous request may have saved it.',
      confirmLabel: 'Try saving again',
    );
    if (confirmed && mounted) {
      setState(() => _uncertainCreate = false);
      await _save();
    }
  }

  String? _requiredText(String? value, int max) {
    final text = value?.trim() ?? '';
    return text.isEmpty || text.length > max
        ? 'Enter between 1 and $max characters.'
        : null;
  }

  List<Widget> _information() => [
    Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          WayhunterTextField(
            label: 'Trip name',
            controller: _name,
            validator: (value) => _requiredText(value, 200),
          ),
          WayhunterTextField(
            label: 'Start date',
            hint: 'YYYY-MM-DD',
            controller: _start,
            validator: (value) => parseTripDate(value?.trim() ?? '') == null
                ? 'Enter a valid start date.'
                : null,
          ),
          WayhunterTextField(
            label: 'End date',
            hint: 'YYYY-MM-DD',
            controller: _end,
            validator: (value) {
              final end = parseTripDate(value?.trim() ?? '');
              final start = parseTripDate(_start.text.trim());
              if (end == null) return 'Enter a valid end date.';
              if (start != null && end.isBefore(start)) {
                return 'End date must be on or after start date.';
              }
              return null;
            },
          ),
          WayhunterTextField(
            label: 'Budget (LKR)',
            controller: _budget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final text = value?.trim() ?? '';
              final amount = num.tryParse(text);
              return amount != null &&
                      amount.isFinite &&
                      RegExp(r'^\d{1,16}(\.\d{1,2})?$').hasMatch(text)
                  ? null
                  : 'Enter a nonnegative amount with up to two decimal places.';
            },
          ),
          WayhunterTextField(
            label: 'Vehicle type',
            controller: _vehicle,
            validator: (value) => _requiredText(value, 100),
          ),
          WayhunterTextField(
            label: 'Group size',
            controller: _headcount,
            keyboardType: TextInputType.number,
            validator: (value) {
              final count = int.tryParse(value?.trim() ?? '');
              return count != null && count >= 1 && count <= 2147483647
                  ? null
                  : 'Enter a valid group size of at least 1.';
            },
          ),
          WayhunterButton.primary(label: 'Continue', onPressed: _continue),
          if (widget.plan == null)
            WayhunterButton.secondary(
              label: 'Add Friends',
              onPressed: () => const AppDestination(friendsRoute).open(context),
            ),
        ],
      ),
    ),
  ];

  List<Widget> _editStops() => [
    WayhunterTextField(label: 'Stop name', controller: _stop),
    WayhunterButton.secondary(label: 'Add stop', onPressed: _addStop),
    WayhunterButton.secondary(
      label: 'Pick on map',
      onPressed: _pickStopLocation,
    ),
    if (_stopLocation case final location?)
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Draft pin ${locationCoordinates(location)}'),
        subtitle: const Text('Add a stop name. Only the name is saved.'),
        trailing: IconButton(
          tooltip: 'Clear draft pin',
          onPressed: () => setState(() => _stopLocation = null),
          icon: const Icon(Icons.close),
        ),
      ),
    if (_stopError case final message?) Text(message),
    for (var i = 0; i < _stops.length; i++)
      Builder(
        builder: (_) {
          final index = i;
          final stop = _stops[index];
          return TripStopTile(
            name: stop.name,
            location: stop.location,
            index: index,
            moveUp: index > 0 ? () => _moveStop(index, index - 1) : null,
            moveDown: index + 1 < _stops.length
                ? () => _moveStop(index, index + 1)
                : null,
            remove: () => setState(() => _stops.removeAt(index)),
          );
        },
      ),
    WayhunterButton.primary(
      label: 'Review trip',
      onPressed: () => setState(() => _step = _Step.review),
    ),
    WayhunterButton.secondary(
      label: 'Back to trip information',
      onPressed: () => setState(() => _step = _Step.information),
    ),
  ];

  List<Widget> _review() => [
    WayhunterSurfaceCard(child: TripSummary(info: _info!)),
    if (widget.plan == null)
      for (final (index, stop) in _stops.indexed) ...[
        Text('${index + 1}. ${stop.name}'),
        if (stop.location case final location?)
          Text('Draft pin ${locationCoordinates(location)}'),
      ],
    if (_error case final message?)
      Semantics(liveRegion: true, child: Text(message)),
    if (_busy) const WayhunterLoadingView(label: 'Saving trip'),
    if (_reloadRequired)
      WayhunterButton.secondary(
        label: 'Back to saved plan',
        onPressed: () => Navigator.of(context).pop(),
      )
    else if (_uncertainCreate) ...[
      const Text(
        'Check My Plans before retrying to avoid creating a duplicate trip.',
      ),
      WayhunterButton.secondary(
        label: 'Check My Plans',
        onPressed: () =>
            Navigator.of(context).pushNamed<void>(myTripPlansRoute),
      ),
      WayhunterButton.secondary(
        label: 'Review retry',
        onPressed: _confirmRetry,
      ),
    ] else
      WayhunterButton.primary(
        label: 'Save trip',
        onPressed: _busy ? null : _save,
      ),
    WayhunterButton.secondary(
      label: 'Back to editing',
      onPressed: _busy
          ? null
          : () => setState(() {
              _step = widget.plan == null ? _Step.stops : _Step.information;
            }),
    ),
  ];

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !_busy && _step == _Step.information,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop || _busy || _step == _Step.information) return;
      setState(() {
        _step = _step == _Step.review && widget.plan == null
            ? _Step.stops
            : _Step.information;
      });
    },
    child: TripContent(
      title: switch (_step) {
        _Step.information =>
          widget.plan == null ? 'Trip information' : 'Edit saved trip',
        _Step.stops => 'Trip stops',
        _Step.review => 'Review trip',
      },
      children: switch (_step) {
        _Step.information => _information(),
        _Step.stops => _editStops(),
        _Step.review => _review(),
      },
    ),
  );
}

class TripStopTile extends StatelessWidget {
  const TripStopTile({
    super.key,
    required this.name,
    required this.index,
    this.location,
    this.moveUp,
    this.moveDown,
    this.remove,
  });

  final String name;
  final int index;
  final LatLng? location;
  final VoidCallback? moveUp;
  final VoidCallback? moveDown;
  final VoidCallback? remove;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Text('${index + 1}'),
    title: Text(name),
    subtitle: location == null
        ? null
        : Text('Draft pin ${locationCoordinates(location!)}'),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Move $name up',
          onPressed: moveUp,
          icon: const Icon(Icons.arrow_upward),
        ),
        IconButton(
          tooltip: 'Move $name down',
          onPressed: moveDown,
          icon: const Icon(Icons.arrow_downward),
        ),
        IconButton(
          tooltip: 'Remove $name',
          onPressed: remove,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    ),
  );
}
