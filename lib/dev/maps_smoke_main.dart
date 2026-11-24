import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wayhunter_mobile/core/services/android_location_services.dart';
import 'package:wayhunter_mobile/core/services/device_interfaces.dart';

const _configChannel = MethodChannel('wayhunter/maps_smoke');

void main() {
  if (!kDebugMode) return;

  runApp(const MaterialApp(home: _MapsSmokeScreen()));
}

class _MapsSmokeScreen extends StatefulWidget {
  const _MapsSmokeScreen();

  @override
  State<_MapsSmokeScreen> createState() => _MapsSmokeScreenState();
}

class _MapsSmokeScreenState extends State<_MapsSmokeScreen> {
  static const _location = AndroidLocationServices();
  static const _serviceDisabled =
      'Location services are off. Turn on Location in Android Settings and try again.';
  static const _locationUnavailable =
      'Current location is unavailable. Try again.';

  late final _configuration = _configChannel.invokeMethod<bool>('isConfigured');
  GoogleMapController? _map;
  Marker? _tapMarker;
  Marker? _locationMarker;
  bool _reading = false;
  String? _status;

  void _placeMarker(LatLng position) {
    setState(() {
      _tapMarker = Marker(
        markerId: const MarkerId('map-tap'),
        position: position,
        infoWindow: const InfoWindow(title: 'Dropped pin'),
      );
    });
  }

  Future<void> _getLocation() async {
    final map = _map;
    if (map == null || _reading) return;

    setState(() {
      _reading = true;
      _status = null;
      _locationMarker = null;
    });

    try {
      if (!await _location.isServiceEnabled()) {
        _status = _serviceDisabled;
        return;
      }
      if (!mounted) return;

      var permission = await _location.check(DevicePermission.location);
      if (!mounted) return;
      if (permission == DevicePermissionStatus.denied) {
        permission = await _location.request(DevicePermission.location);
      }
      if (!mounted) return;
      if (permission != DevicePermissionStatus.granted) {
        _status = _permissionMessage(permission);
        return;
      }

      final sample = await _location.read();
      if (!mounted) return;

      final position = LatLng(sample.latitude, sample.longitude);
      setState(() {
        _locationMarker = Marker(
          markerId: const MarkerId('current-location'),
          position: position,
          infoWindow: const InfoWindow(title: 'Current location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        );
      });
      await map.animateCamera(CameraUpdate.newLatLngZoom(position, 16));
      _status = 'Centered on your current location.';
    } on LocationReadException catch (error) {
      _status = switch (error.reason) {
        LocationFailure.serviceDisabled => _serviceDisabled,
        LocationFailure.permissionDenied => _permissionMessage(
          DevicePermissionStatus.denied,
        ),
        LocationFailure.timedOut => 'Location timed out. Try again.',
        LocationFailure.unavailable => _locationUnavailable,
      };
    } on PlatformException {
      _status = 'Could not move the map to your current location. Try again.';
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  String _permissionMessage(
    DevicePermissionStatus permission,
  ) => switch (permission) {
    DevicePermissionStatus.denied =>
      'Location permission denied. Tap Get current location to try again.',
    DevicePermissionStatus.permanentlyDenied =>
      'Location permission is blocked. Allow Location in Android Settings for this app.',
    DevicePermissionStatus.unavailable =>
      'Could not check location permission. Review this app’s permissions in Android Settings.',
    DevicePermissionStatus.granted => 'Location permission granted.',
  };

  @override
  Widget build(BuildContext context) {
    final supported =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return Scaffold(
      appBar: AppBar(title: const Text('Wayhunter Google Maps Test')),
      body: SafeArea(
        child: supported
            ? FutureBuilder<bool?>(
                future: _configuration,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return _message('Checking Maps configuration…');
                  }
                  if (snapshot.hasError) {
                    return _message(
                      'Could not check Maps configuration. Rebuild and run the Android debug app.',
                    );
                  }
                  if (snapshot.data != true) {
                    return _message(
                      'Google Maps API key is missing. Create '
                      'android/maps.local.properties and add an unquoted line '
                      'MAPS_API_KEY=YOUR_ANDROID_RESTRICTED_KEY. Replace the '
                      'example value with your key, then rebuild and run this target.',
                    );
                  }
                  return _buildMap();
                },
              )
            : _message('Run this test on Android.'),
      ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(padding: const EdgeInsets.all(24), child: Text(text)),
  );

  Widget _buildMap() => Column(
    children: [
      Expanded(
        child: GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(7.8731, 80.7718),
            zoom: 7,
          ),
          onMapCreated: (map) => setState(() => _map = map),
          onTap: _placeMarker,
          mapToolbarEnabled: false,
          markers: {?_tapMarker, ?_locationMarker},
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('Drag to pan, pinch to zoom, and tap to place a pin.'),
            FilledButton(
              onPressed: _map == null || _reading ? null : _getLocation,
              child: const Text('Get current location'),
            ),
            if ((_reading ? 'Reading location…' : _status) case final status?)
              Semantics(liveRegion: true, child: Text(status)),
          ],
        ),
      ),
    ],
  );
}
