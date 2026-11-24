import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wayhunter_mobile/core/services/android_location_services.dart';
import 'package:wayhunter_mobile/core/services/device_interfaces.dart';
import 'package:wayhunter_mobile/dev/native_smoke_main.dart' as smoke;

void main() {
  const services = AndroidLocationServices();
  late _LocationPlatform platform;

  setUp(() {
    final original = GeolocatorPlatform.instance;
    platform = _LocationPlatform();
    GeolocatorPlatform.instance = platform;
    addTearDown(() async {
      GeolocatorPlatform.instance = original;
      await platform.serviceChanges.close();
    });
  });

  test('maps native location permission checks and requests', () async {
    const expectedStatuses = {
      LocationPermission.whileInUse: DevicePermissionStatus.granted,
      LocationPermission.always: DevicePermissionStatus.granted,
      LocationPermission.denied: DevicePermissionStatus.denied,
      LocationPermission.deniedForever:
          DevicePermissionStatus.permanentlyDenied,
      LocationPermission.unableToDetermine: DevicePermissionStatus.unavailable,
    };
    for (final entry in expectedStatuses.entries) {
      platform.permission = entry.key;
      expect(await services.check(DevicePermission.location), entry.value);
      expect(await services.request(DevicePermission.location), entry.value);
    }
  });

  test('leaves camera and microphone permissions unavailable', () async {
    for (final permission in [
      DevicePermission.camera,
      DevicePermission.microphone,
    ]) {
      expect(
        await services.check(permission),
        DevicePermissionStatus.unavailable,
      );
      expect(
        await services.request(permission),
        DevicePermissionStatus.unavailable,
      );
    }
    expect(platform.permissionChecks, 0);
    expect(platform.permissionRequests, 0);
  });

  test(
    'stops before starting a fix when services are off or access is denied',
    () async {
      platform.enabled = false;
      await expectLater(
        services.read(),
        _throwsLocationFailure(LocationFailure.serviceDisabled),
      );
      expect(platform.permissionChecks, 0);

      platform.enabled = true;
      platform.permission = LocationPermission.denied;
      await expectLater(
        services.read(),
        _throwsLocationFailure(LocationFailure.permissionDenied),
      );
      expect(platform.permissionRequests, 0);
      expect(platform.readSettings, isNull);
    },
  );

  test(
    'sets the 15-second limit and maps errors from the native read',
    () async {
      platform.permission = LocationPermission.whileInUse;
      final failures = {
        TimeoutException('No fix'): LocationFailure.timedOut,
        const LocationServiceDisabledException():
            LocationFailure.serviceDisabled,
        const PermissionDeniedException('Permission revoked'):
            LocationFailure.permissionDenied,
        Exception('Provider unavailable'): LocationFailure.unavailable,
      };
      for (final entry in failures.entries) {
        platform.readError = entry.key;
        await expectLater(services.read(), _throwsLocationFailure(entry.value));
      }
      expect(platform.readSettings?.timeLimit, const Duration(seconds: 15));
    },
  );

  testWidgets('checks and requests permission without reading a fix', (
    tester,
  ) async {
    smoke.main();
    await tester.pumpAndSettle();
    expect(find.text('WayHunter GPS Test'), findsOneWidget);

    await tester.tap(find.text('Check location permission'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Location permission denied.'), findsOneWidget);
    expect(platform.permissionChecks, 1);
    expect(platform.permissionRequests, 0);

    platform.requestResult = LocationPermission.deniedForever;
    await tester.tap(find.text('Request location permission'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Location permission is blocked.'),
      findsOneWidget,
    );
    expect(platform.permissionRequests, 1);
    expect(platform.readSettings, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'shows granted foreground permission after a request and a check',
    (tester) async {
      smoke.main();
      await tester.pumpAndSettle();

      platform.permission = LocationPermission.whileInUse;
      final granted = find.text('Location permission granted.');
      await tester.tap(find.text('Request location permission'));
      await tester.pumpAndSettle();
      expect(granted, findsOneWidget);
      expect(platform.permissionRequests, 1);
      expect(platform.permissionChecks, 0);

      await tester.tap(find.text('Check location permission'));
      await tester.pumpAndSettle();
      expect(granted, findsOneWidget);
      expect(platform.permissionChecks, 1);
      expect(platform.permissionRequests, 1);
      expect(platform.readSettings, isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'stops Get current location when Android denies the permission request',
    (tester) async {
      platform.permission = LocationPermission.denied;
      smoke.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get current location'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Location permission denied. Tap Request location permission to try again.',
        ),
        findsOneWidget,
      );
      expect(platform.permissionChecks, 1);
      expect(platform.permissionRequests, 1);
      expect(platform.readSettings, isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'shows Android Settings guidance when location access is permanently denied',
    (tester) async {
      platform.permission = LocationPermission.denied;
      platform.requestResult = LocationPermission.deniedForever;
      smoke.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get current location'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Open this app’s permissions in Android Settings'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Tap Request location permission to try again.'),
        findsNothing,
      );
      expect(platform.permissionChecks, 1);
      expect(platform.permissionRequests, 1);
      expect(platform.readSettings, isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'shows recovery guidance and stops the read when GPS is disabled',
    (tester) async {
      platform.enabled = false;
      smoke.main();
      await tester.pumpAndSettle();
      expect(find.text('GPS disabled'), findsOneWidget);

      await tester.tap(find.text('Get current location'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Turn on Location in Android Settings'),
        findsOneWidget,
      );
      expect(platform.permissionChecks, 0);
      expect(platform.permissionRequests, 0);
      expect(platform.readSettings, isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'updates GPS status and displays recovery guidance after a timeout',
    (tester) async {
      platform.enabled = false;
      smoke.main();
      await tester.pumpAndSettle();
      expect(find.text('GPS disabled'), findsOneWidget);

      platform.enabled = true;
      platform.serviceChanges.add(ServiceStatus.enabled);
      await tester.pumpAndSettle();
      expect(find.text('GPS enabled'), findsOneWidget);

      platform.permission = LocationPermission.whileInUse;
      platform.readError = TimeoutException('No fix');
      await tester.tap(find.text('Get current location'));
      await tester.pumpAndSettle();
      expect(find.textContaining('timed out before a fix'), findsOneWidget);
      expect(find.textContaining('Latitude:'), findsNothing);
      expect(find.textContaining('Longitude:'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('displays a successful fix from the mocked Android provider', (
    tester,
  ) async {
    final capturedAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
    platform.permission = LocationPermission.whileInUse;
    platform.position = Position(
      latitude: 1.25,
      longitude: -2.5,
      accuracy: 4.5,
      timestamp: capturedAt,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    smoke.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get current location'));
    await tester.pumpAndSettle();

    expect(find.text('Latitude: 1.25'), findsOneWidget);
    expect(find.text('Longitude: -2.5'), findsOneWidget);
    expect(find.text('Accuracy: 4.5 m'), findsOneWidget);
    expect(find.text('Captured at: 2026-01-02T03:04:05.000Z'), findsOneWidget);
    expect(platform.permissionRequests, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'shows recovery guidance and allows retry when the provider is unavailable',
    (tester) async {
      platform.permission = LocationPermission.whileInUse;
      platform.readError = Exception('Native provider failure');
      smoke.main();
      await tester.pumpAndSettle();

      final getLocation = find.text('Get current location');
      await tester.tap(getLocation);
      await tester.pumpAndSettle();

      final unavailable = find.textContaining('Could not read location.');
      expect(unavailable, findsOneWidget);
      expect(find.textContaining('Native provider failure'), findsNothing);
      expect(find.textContaining('Latitude:'), findsNothing);
      expect(find.textContaining('Longitude:'), findsNothing);

      platform.readError = TimeoutException('No fix');
      await tester.tap(getLocation);
      await tester.pumpAndSettle();

      expect(unavailable, findsNothing);
      expect(find.textContaining('timed out before a fix'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

Matcher _throwsLocationFailure(LocationFailure reason) => throwsA(
  isA<LocationReadException>().having(
    (error) => error.reason,
    'reason',
    reason,
  ),
);

class _LocationPlatform extends GeolocatorPlatform {
  final serviceChanges = StreamController<ServiceStatus>.broadcast();
  bool enabled = true;
  var permission = LocationPermission.denied;
  LocationPermission? requestResult;
  int permissionChecks = 0;
  int permissionRequests = 0;
  LocationSettings? readSettings;
  Object? readError;
  Position? position;

  @override
  Future<LocationPermission> checkPermission() async {
    permissionChecks++;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return requestResult ?? permission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Stream<ServiceStatus> getServiceStatusStream() => serviceChanges.stream;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    readSettings = locationSettings;
    if (readError case final error?) throw error;
    return position ?? (throw StateError('Unexpected location read.'));
  }
}
