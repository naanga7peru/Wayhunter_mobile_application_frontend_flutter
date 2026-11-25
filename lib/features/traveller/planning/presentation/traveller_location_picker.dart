import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wayhunter_mobile/core/services/device_interfaces.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';

String locationCoordinates(LatLng point) =>
    '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

class TravellerLocationPicker extends StatefulWidget {
  const TravellerLocationPicker({
    super.key,
    required this.maps,
    required this.permissions,
    required this.location,
    this.initialSelection,
  });

  final MapProvider maps;
  final DevicePermissions permissions;
  final CurrentLocation location;
  final LatLng? initialSelection;

  @override
  State<TravellerLocationPicker> createState() =>
      _TravellerLocationPickerState();
}

enum _MapState { checking, starting, ready, unavailable }

class _TravellerLocationPickerState extends State<TravellerLocationPicker> {
  static const _startTimeout = Duration(seconds: 15);
  static const _permission = DevicePermission.location;
  static const _locationUnavailable = 'Could not get your location. Try again.';
  static const _permissionDenied =
      'Location permission denied. You can still tap the map.';
  late LatLng? _selection = widget.initialSelection;
  _MapState _mapState = _MapState.checking;
  GoogleMapController? _map;
  Timer? _mapTimeout;
  bool _reading = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _checkMap();
  }

  Future<void> _checkMap() async {
    try {
      if (await widget.maps.availability().timeout(_startTimeout) ==
              MapProviderStatus.available &&
          mounted) {
        setState(() => _mapState = _MapState.starting);
        _mapTimeout = Timer(_startTimeout, _mapUnavailable);
        return;
      }
    } on Exception {
      // A missing or unreachable platform service uses the manual-stop fallback.
    }
    _mapUnavailable();
  }

  void _mapUnavailable() {
    if (mounted) setState(() => _mapState = _MapState.unavailable);
  }

  void _mapCreated(GoogleMapController map) {
    if (!mounted || _mapState != _MapState.starting) return;
    _mapTimeout?.cancel();
    setState(() {
      _map = map;
      _mapState = _MapState.ready;
    });
  }

  @override
  void dispose() {
    _mapTimeout?.cancel();
    super.dispose();
  }

  void _select(LatLng point) {
    setState(() {
      _selection = point;
      _status = null;
    });
  }

  Future<void> _useCurrentLocation() async {
    final map = _map;
    if (map == null || _reading) return;
    setState(() {
      _reading = true;
      _status = null;
    });

    try {
      var permission = await widget.permissions.check(_permission);
      if (!mounted) return;
      if (permission == DevicePermissionStatus.denied) {
        permission = await widget.permissions.request(_permission);
      }
      if (!mounted) return;
      if (permission != DevicePermissionStatus.granted) {
        _status = switch (permission) {
          DevicePermissionStatus.denied => _permissionDenied,
          DevicePermissionStatus.permanentlyDenied =>
            'Allow Location for Wayhunter in Android Settings, then try again.',
          _ => 'Location permission is unavailable. You can still tap the map.',
        };
        return;
      }

      final sample = await widget.location.read();
      if (!mounted) return;
      if (!sample.latitude.isFinite ||
          !sample.longitude.isFinite ||
          sample.latitude.abs() > 90 ||
          sample.longitude.abs() > 180) {
        _status = _locationUnavailable;
        return;
      }
      final point = LatLng(sample.latitude, sample.longitude);
      _select(point);
      try {
        await map.animateCamera(CameraUpdate.newLatLngZoom(point, 16));
      } on Exception {
        _status = 'Location selected. The map could not move to it.';
      }
    } on LocationReadException catch (error) {
      _status = switch (error.reason) {
        LocationFailure.serviceDisabled =>
          'Turn on Location in Android Settings, then try again.',
        LocationFailure.permissionDenied => _permissionDenied,
        LocationFailure.timedOut => 'Location timed out. Try again.',
        LocationFailure.unavailable => _locationUnavailable,
      };
    } on Exception {
      _status = _locationUnavailable;
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selection;
    final ready = _mapState == _MapState.ready;
    return Scaffold(
      appBar: AppBar(title: const Text('Pick a stop location')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: switch (_mapState) {
                _MapState.checking => const Center(
                  child: Text('Checking map…'),
                ),
                _MapState.unavailable => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Google Maps is unavailable. Return to Trip stops to enter a name.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                _MapState.starting || _MapState.ready => Stack(
                  fit: StackFit.expand,
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target:
                            widget.initialSelection ??
                            const LatLng(7.8731, 80.7718),
                        zoom: widget.initialSelection == null ? 7 : 16,
                      ),
                      onMapCreated: _mapCreated,
                      onTap: (point) {
                        if (!_reading) _select(point);
                      },
                      mapToolbarEnabled: false,
                      markers: {
                        if (selected != null)
                          Marker(
                            markerId: const MarkerId('traveller-stop'),
                            position: selected,
                            infoWindow: const InfoWindow(
                              title: 'Selected stop',
                            ),
                          ),
                      },
                    ),
                    if (!ready)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              },
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ready) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        selected == null
                            ? 'Tap the map to select a location.'
                            : 'Selected location ${locationCoordinates(selected)}',
                      ),
                    ),
                    if ((_reading ? 'Getting your location…' : _status)
                        case final message?)
                      Semantics(liveRegion: true, child: Text(message)),
                    WayhunterButton.secondary(
                      label: 'Use current location',
                      onPressed: _reading ? null : _useCurrentLocation,
                    ),
                  ],
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      WayhunterButton.primary(
                        label: 'Confirm location',
                        onPressed: ready && selected != null && !_reading
                            ? () => Navigator.of(context).pop(selected)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
