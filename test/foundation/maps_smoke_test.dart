import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// The plugin's platform interface is needed only to replace its native view.
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:wayhunter_mobile/dev/maps_smoke_main.dart' as smoke;

void main() {
  const configChannel = MethodChannel('wayhunter/maps_smoke');
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  final getLocation = find.text('Get current location');
  late _MapPlatform map;
  late _GpsPlatform gps;

  setUp(() {
    final originalMaps = GoogleMapsFlutterPlatform.instance;
    final originalGps = GeolocatorPlatform.instance;
    map = _MapPlatform();
    gps = _GpsPlatform();
    GoogleMapsFlutterPlatform.instance = map;
    GeolocatorPlatform.instance = gps;
    addTearDown(() async {
      GoogleMapsFlutterPlatform.instance = originalMaps;
      GeolocatorPlatform.instance = originalGps;
      await map.taps.close();
    });
  });

  Future<void> start(WidgetTester tester, {bool configured = true}) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(configChannel, (call) async {
      expect(call.method, 'isConfigured');
      return configured;
    });
    messenger.setMockMethodCallHandler(
      _MapPlatform.nativeMap,
      (_) async => null,
    );
    smoke.main();
    await tester.pumpAndSettle();
  }

  testWidgets('shows local setup and skips the map without a key', (
    tester,
  ) async {
    await start(tester, configured: false);

    expect(
      find.textContaining('android/maps.local.properties'),
      findsOneWidget,
    );
    expect(
      find.textContaining('MAPS_API_KEY=YOUR_ANDROID_RESTRICTED_KEY'),
      findsOneWidget,
    );
    expect(find.byType(GoogleMap), findsNothing);
    expect(getLocation, findsNothing);
  }, variant: android);

  testWidgets('enables pan and zoom and moves the pin on each tap', (
    tester,
  ) async {
    await start(tester);
    final mapFinder = find.byType(GoogleMap);
    expect(tester.widget<GoogleMap>(mapFinder).scrollGesturesEnabled, isTrue);
    expect(tester.widget<GoogleMap>(mapFinder).zoomGesturesEnabled, isTrue);

    for (final point in [const LatLng(7, 80), const LatLng(8, 81)]) {
      map.taps.add(MapTapEvent(map.mapId, point));
      await tester.pumpAndSettle();

      final pin = tester.widget<GoogleMap>(mapFinder).markers.single;
      expect(pin.markerId, const MarkerId('map-tap'));
      expect(pin.position, point);
    }
    expect(gps.reads, 0);
  }, variant: android);

  testWidgets('requests foreground permission and centers on the GPS fix', (
    tester,
  ) async {
    gps.permission = LocationPermission.denied;
    gps.requestResult = LocationPermission.whileInUse;
    await start(tester);
    const pin = LatLng(7, 80);
    map.taps.add(MapTapEvent(map.mapId, pin));
    await tester.pumpAndSettle();
    await tester.tap(getLocation);
    await tester.pumpAndSettle();

    const position = LatLng(6.9, 79.8);
    expect(gps.permissionRequests, 1);
    expect(gps.reads, 1);
    expect(
      map.cameraUpdates.single.toJson(),
      CameraUpdate.newLatLngZoom(position, 16).toJson(),
    );
    final markers = tester.widget<GoogleMap>(find.byType(GoogleMap)).markers;
    expect(
      {for (final marker in markers) marker.markerId.value: marker.position},
      {'map-tap': pin, 'current-location': position},
    );
    expect(find.text('Centered on your current location.'), findsOneWidget);
  }, variant: android);

  testWidgets(
    'stops before reading when GPS is disabled or permission is denied',
    (tester) async {
      gps.enabled = false;
      await start(tester);
      await tester.tap(getLocation);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Turn on Location in Android Settings'),
        findsOneWidget,
      );
      expect(gps.permissionRequests, 0);

      gps.enabled = true;
      gps.permission = LocationPermission.denied;
      await tester.tap(getLocation);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Location permission denied.'),
        findsOneWidget,
      );
      expect(gps.permissionRequests, 1);

      gps.permission = LocationPermission.deniedForever;
      await tester.tap(getLocation);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Location permission is blocked.'),
        findsOneWidget,
      );
      expect(gps.permissionRequests, 1);
      expect(gps.reads, 0);
      expect(map.cameraUpdates, isEmpty);
    },
    variant: android,
  );

  testWidgets(
    'leaves the camera in place when the fix fails and allows retry',
    (tester) async {
      await start(tester);
      gps.error = Exception('Provider unavailable');
      await tester.tap(getLocation);
      await tester.pumpAndSettle();
      expect(
        find.text('Current location is unavailable. Try again.'),
        findsOneWidget,
      );

      gps.error = TimeoutException('No fix');
      await tester.tap(getLocation);
      await tester.pumpAndSettle();
      expect(find.text('Location timed out. Try again.'), findsOneWidget);
      expect(map.cameraUpdates, isEmpty);

      gps.error = null;
      await tester.tap(getLocation);
      await tester.pumpAndSettle();
      expect(gps.reads, 3);
      expect(map.cameraUpdates, hasLength(1));
    },
    variant: android,
  );
}

class _MapPlatform extends MethodChannelGoogleMapsFlutter {
  static const nativeMap = MethodChannel('test/wayhunter_maps_view');
  final taps = StreamController<MapTapEvent>.broadcast();
  final cameraUpdates = <CameraUpdate>[];
  final _createdViews = <int>{};
  late int mapId;

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    if (_createdViews.add(creationId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onPlatformViewCreated(creationId);
      });
    }
    return const SizedBox.expand();
  }

  @override
  Future<void> init(int mapId) async => this.mapId = mapId;

  @override
  MethodChannel channel(int mapId) => nativeMap;

  @override
  Stream<MapTapEvent> onTap({required int mapId}) => taps.stream;

  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {
    cameraUpdates.add(cameraUpdate);
  }
}

class _GpsPlatform extends GeolocatorPlatform {
  bool enabled = true;
  var permission = LocationPermission.whileInUse;
  var requestResult = LocationPermission.denied;
  int permissionRequests = 0;
  int reads = 0;
  Exception? error;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission = requestResult;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    reads++;
    if (error case final failure?) throw failure;
    return Position(
      latitude: 6.9,
      longitude: 79.8,
      timestamp: DateTime.utc(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}
