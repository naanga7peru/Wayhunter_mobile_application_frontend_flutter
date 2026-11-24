import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/services/android_location_services.dart';
import 'package:wayhunter_mobile/core/services/device_interfaces.dart';

void main() {
  if (!kDebugMode) return;

  runApp(const MaterialApp(home: _GpsTestScreen()));
}

class _GpsTestScreen extends StatefulWidget {
  const _GpsTestScreen();

  @override
  State<_GpsTestScreen> createState() => _GpsTestScreenState();
}

class _GpsTestScreenState extends State<_GpsTestScreen> {
  static const _location = AndroidLocationServices();
  static const _serviceDisabledMessage =
      'Location services are off. Turn on Location in Android Settings, then try again.';

  late final _initialGpsStatus = _location.isServiceEnabled();
  late final _gpsStatusChanges = _location.serviceEnabledChanges();

  String? _permissionProgress;
  bool _reading = false;
  String? _status;
  LocationSample? _sample;

  Future<void> _updatePermission(
    Future<DevicePermissionStatus> Function(DevicePermission) action,
    String progress,
  ) async {
    setState(() {
      _permissionProgress = progress;
      _status = null;
    });

    final permission = await action(DevicePermission.location);
    if (!mounted) return;
    setState(() {
      _permissionProgress = null;
      _status = _permissionMessage(permission);
    });
  }

  Future<void> _readLocation() async {
    setState(() {
      _reading = true;
      _status = null;
      _sample = null;
    });

    try {
      if (!await _location.isServiceEnabled()) {
        _status = _serviceDisabledMessage;
        return;
      }

      var permission = await _location.check(DevicePermission.location);
      if (permission == DevicePermissionStatus.denied) {
        permission = await _location.request(DevicePermission.location);
      }
      if (permission == DevicePermissionStatus.granted) {
        _sample = await _location.read();
      } else {
        _status = _permissionMessage(permission);
      }
    } on LocationReadException catch (error) {
      _status = switch (error.reason) {
        LocationFailure.serviceDisabled => _serviceDisabledMessage,
        LocationFailure.permissionDenied => _permissionMessage(
          DevicePermissionStatus.denied,
        ),
        LocationFailure.timedOut =>
          'Location timed out before a fix was available. Try Get current location again.',
        LocationFailure.unavailable =>
          'Could not read location. Check that Location is on in Android Settings, then try again.',
      };
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  String _permissionMessage(
    DevicePermissionStatus permission,
  ) => switch (permission) {
    DevicePermissionStatus.granted => 'Location permission granted.',
    DevicePermissionStatus.denied =>
      'Location permission denied. Tap Request location permission to try again.',
    DevicePermissionStatus.permanentlyDenied =>
      'Location permission is blocked. Open this app’s permissions in Android Settings and allow Location.',
    DevicePermissionStatus.unavailable =>
      'Could not check location permission. Review this app’s permissions in Android Settings.',
  };

  Widget _gpsStatusLabel(AsyncSnapshot<bool> status) =>
      Text(switch (status.data) {
        true => 'GPS enabled',
        false => 'GPS disabled',
        null =>
          status.hasError ? 'GPS status unavailable' : 'Checking GPS status…',
      });

  @override
  Widget build(BuildContext context) {
    final supported =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    final busy = _permissionProgress != null || _reading;

    return Scaffold(
      appBar: AppBar(title: const Text('WayHunter GPS Test')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (supported) ...[
              StreamBuilder<bool>(
                stream: _gpsStatusChanges,
                builder: (context, updates) {
                  if (updates.hasData || updates.hasError) {
                    return _gpsStatusLabel(updates);
                  }
                  return FutureBuilder<bool>(
                    future: _initialGpsStatus,
                    builder: (context, initial) => _gpsStatusLabel(initial),
                  );
                },
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => _updatePermission(
                        _location.check,
                        'Checking location permission…',
                      ),
                child: const Text('Check location permission'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => _updatePermission(
                        _location.request,
                        'Requesting location permission…',
                      ),
                child: const Text('Request location permission'),
              ),
              FilledButton(
                onPressed: busy ? null : _readLocation,
                child: const Text('Get current location'),
              ),
            ] else
              const Text('Run this test on Android.'),
            if (_permissionProgress case final progress?) Text(progress),
            if (_reading) const Text('Reading location…'),
            if (_status case final status?)
              Semantics(liveRegion: true, child: Text(status)),
            if (_sample case final sample?) ...[
              const SizedBox(height: 16),
              SelectableText('Latitude: ${sample.latitude}'),
              SelectableText('Longitude: ${sample.longitude}'),
              Text('Accuracy: ${sample.accuracyMeters.toStringAsFixed(1)} m'),
              Text(
                'Captured at: ${sample.capturedAt.toUtc().toIso8601String()}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
