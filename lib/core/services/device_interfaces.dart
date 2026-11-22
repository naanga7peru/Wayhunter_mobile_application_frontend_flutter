enum DevicePermission { location, camera, microphone }

enum DevicePermissionStatus { granted, denied, permanentlyDenied, unavailable }

abstract interface class DevicePermissions {
  Future<DevicePermissionStatus> check(DevicePermission permission);
  Future<DevicePermissionStatus> request(DevicePermission permission);
}

class LocationSample {
  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
}

abstract interface class CurrentLocation {
  Future<LocationSample> read();
}

enum MapProviderStatus { available, unavailable }

abstract interface class MapProvider {
  Future<MapProviderStatus> availability();
}

class LiveCapture {
  const LiveCapture({required this.localUri, required this.capturedAt});

  final Uri localUri;
  final DateTime capturedAt;
}

abstract interface class LiveMediaCapture {
  Future<LiveCapture> takePhoto();
  Future<LiveCapture> recordVideo();
}

enum MediaUploadStatus {
  unavailable,
  queued,
  uploading,
  completed,
  failed,
  cancelled,
}

abstract interface class MediaUploadMonitor {
  Future<MediaUploadStatus> status(String operationId);
}

class DeviceUnavailableException implements Exception {
  const DeviceUnavailableException();
}

class UnavailableDeviceServices
    implements
        DevicePermissions,
        CurrentLocation,
        MapProvider,
        LiveMediaCapture,
        MediaUploadMonitor {
  const UnavailableDeviceServices();

  @override
  Future<DevicePermissionStatus> check(DevicePermission permission) async =>
      DevicePermissionStatus.unavailable;

  @override
  Future<DevicePermissionStatus> request(DevicePermission permission) async =>
      DevicePermissionStatus.unavailable;

  @override
  Future<LocationSample> read() async =>
      throw const DeviceUnavailableException();

  @override
  Future<MapProviderStatus> availability() async =>
      MapProviderStatus.unavailable;

  @override
  Future<LiveCapture> takePhoto() async =>
      throw const DeviceUnavailableException();

  @override
  Future<LiveCapture> recordVideo() async =>
      throw const DeviceUnavailableException();

  @override
  Future<MediaUploadStatus> status(String operationId) async =>
      MediaUploadStatus.unavailable;
}
