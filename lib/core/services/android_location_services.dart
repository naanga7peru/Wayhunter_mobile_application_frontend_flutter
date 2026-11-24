import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:wayhunter_mobile/core/services/device_interfaces.dart';

class AndroidLocationServices implements DevicePermissions, CurrentLocation {
  const AndroidLocationServices();

  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 15),
  );

  @override
  Future<DevicePermissionStatus> check(DevicePermission permission) =>
      _locationPermission(permission, Geolocator.checkPermission);

  @override
  Future<DevicePermissionStatus> request(DevicePermission permission) =>
      _locationPermission(permission, Geolocator.requestPermission);

  Future<DevicePermissionStatus> _locationPermission(
    DevicePermission permission,
    Future<LocationPermission> Function() readPermission,
  ) async {
    if (permission != DevicePermission.location) {
      return DevicePermissionStatus.unavailable;
    }

    try {
      return switch (await readPermission()) {
        LocationPermission.always ||
        LocationPermission.whileInUse => DevicePermissionStatus.granted,
        LocationPermission.denied => DevicePermissionStatus.denied,
        LocationPermission.deniedForever =>
          DevicePermissionStatus.permanentlyDenied,
        LocationPermission.unableToDetermine =>
          DevicePermissionStatus.unavailable,
      };
    } on Exception {
      return DevicePermissionStatus.unavailable;
    }
  }

  Future<bool> isServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } on Exception {
      throw const LocationReadException(LocationFailure.unavailable);
    }
  }

  Stream<bool> serviceEnabledChanges() => Geolocator.getServiceStatusStream()
      .map((status) => status == ServiceStatus.enabled);

  @override
  Future<LocationSample> read() async {
    if (!await isServiceEnabled()) {
      throw const LocationReadException(LocationFailure.serviceDisabled);
    }

    final permission = await check(DevicePermission.location);
    if (permission != DevicePermissionStatus.granted) {
      throw LocationReadException(
        permission == DevicePermissionStatus.unavailable
            ? LocationFailure.unavailable
            : LocationFailure.permissionDenied,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _settings,
      );
      return LocationSample(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAt: position.timestamp,
      );
    } on TimeoutException {
      throw const LocationReadException(LocationFailure.timedOut);
    } on LocationServiceDisabledException {
      throw const LocationReadException(LocationFailure.serviceDisabled);
    } on PermissionDeniedException {
      throw const LocationReadException(LocationFailure.permissionDenied);
    } on Exception {
      throw const LocationReadException(LocationFailure.unavailable);
    }
  }
}
