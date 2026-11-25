import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// The platform interface replaces the native Google Maps view in widget tests.
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/services/device_interfaces.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/traveller/planning/data/trip_plans_api.dart';
import 'package:wayhunter_mobile/features/traveller/planning/domain/trip_plan.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

const _id = '10000000-0000-0000-0000-000000000001';
const _stopA = '10000000-0000-0000-0000-000000000002';
const _stopB = '10000000-0000-0000-0000-000000000003';
const _owner = '10000000-0000-0000-0000-000000000004';
const _version = 'AAAAAAAAAAE=';
const _nextVersion = 'AAAAAAAAAAI=';
const _base = '/api/mobile/trip-plans';

Map<String, Object?> _stop(String id, String name, int index) => {
  'stopId': id,
  'name': name,
  'orderIndex': index,
  'placeId': null,
  'latitude': null,
  'longitude': null,
};

Map<String, Object?> _plan({
  String name = 'Synthetic trip',
  String version = _version,
  List<Map<String, Object?>> stops = const [],
}) => {
  'tripPlanId': _id,
  'tripName': name,
  'startDate': '2026-11-27',
  'endDate': '2026-11-28',
  'budgetLkr': 8500.50,
  'vehicleType': 'Van',
  'headcount': 3,
  'rowVersion': version,
  'stops': stops,
};

TransportResponse _json(int status, Object data) =>
    TransportResponse(status, utf8.encode(jsonEncode(data)));

class _TripTransport implements HttpTransport {
  final requests = <TransportRequest>[];
  late FutureOr<TransportResponse> Function(TransportRequest) respond;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return respond(request);
  }
}

class _MemoryStore implements CredentialStore {
  SessionCredential? value;
  @override
  Future<SessionCredential?> read() async => value;
  @override
  Future<void> write(SessionCredential credential) async => value = credential;
  @override
  Future<void> clear() async => value = null;
}

class _Harness {
  final store = _MemoryStore();
  final transport = _TripTransport();
  late final session = SessionController(store);
  late final client = ApiClient(
    baseUrl: Uri.https('example.invalid'),
    transport: transport,
    tokens: session,
  );

  SessionCredential get credential => const SessionCredential(
    user: UserRef(_owner),
    accessToken: 'synthetic-owner',
  );
  TripPlansApi get api => TripPlansApi(client, session);

  Future<void> open(WidgetTester tester, {_PickerServices? picker}) async {
    store.value = credential;
    await tester.pumpWidget(
      FoundationServices(
        api: client,
        session: session,
        maps: picker ?? const UnavailableDeviceServices(),
        permissions: picker ?? const UnavailableDeviceServices(),
        location: picker ?? const UnavailableDeviceServices(),
        child: const WayhunterApp.authenticated(apiConfigured: true),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Traveler').first);
    expect(find.text('Traveller'), findsOneWidget);
  }

  void mock(FutureOr<TransportResponse> Function(TransportRequest) respond) {
    transport.respond = (request) {
      if (request.uri.path == '/api/mobile/identity/me') {
        return _json(200, {
          'userId': _owner,
          'displayName': 'Synthetic visitor',
          'email': 'visitor@example.invalid',
        });
      }
      if (request.uri.path == '/api/mobile/advertisements/active') {
        return _json(200, []);
      }
      if (request.uri.path == '/api/mobile/auth/logout') {
        return const TransportResponse(204, []);
      }
      expect(request.headers['Authorization'], 'Bearer synthetic-owner');
      return respond(request);
    };
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, int index, String value) async {
  final field = find.byType(TextFormField).at(index);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Map<String, dynamic> body(TransportRequest request) =>
    jsonDecode(request.body!) as Map<String, dynamic>;

class _PickerServices
    implements MapProvider, DevicePermissions, CurrentLocation {
  MapProviderStatus mapStatus = MapProviderStatus.available;
  DevicePermissionStatus permission = DevicePermissionStatus.denied;
  DevicePermissionStatus requestResult = DevicePermissionStatus.denied;
  LocationFailure? failure;
  int permissionRequests = 0;
  int reads = 0;

  static const fix = LatLng(6.9, 79.8);

  @override
  Future<MapProviderStatus> availability() async => mapStatus;

  @override
  Future<DevicePermissionStatus> check(DevicePermission permission) async {
    expect(permission, DevicePermission.location);
    return this.permission;
  }

  @override
  Future<DevicePermissionStatus> request(DevicePermission permission) async {
    expect(permission, DevicePermission.location);
    permissionRequests++;
    return requestResult;
  }

  @override
  Future<LocationSample> read() async {
    reads++;
    if (failure case final reason?) throw LocationReadException(reason);
    return LocationSample(
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracyMeters: 5,
      capturedAt: DateTime.utc(2026),
    );
  }
}

class _PickerMap extends MethodChannelGoogleMapsFlutter {
  static const native = MethodChannel('test/traveller_picker_map');
  bool createsView = true;
  final _created = <int>{};
  final cameraUpdates = <CameraUpdate>[];

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    if (createsView && _created.add(creationId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onPlatformViewCreated(creationId);
      });
    }
    return const SizedBox.expand();
  }

  @override
  Future<void> init(int mapId) async {}

  @override
  MethodChannel channel(int mapId) => native;

  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> animateCamera(CameraUpdate update, {required int mapId}) async {
    cameraUpdates.add(update);
  }
}

_PickerMap _mockPickerMap(WidgetTester tester) {
  final original = GoogleMapsFlutterPlatform.instance;
  final map = _PickerMap();
  GoogleMapsFlutterPlatform.instance = map;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _PickerMap.native,
    (_) async => null,
  );
  addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
  return map;
}

Future<void> _openNewTripStops(
  WidgetTester tester,
  _Harness harness,
  _PickerServices picker,
) async {
  await harness.open(tester, picker: picker);
  await tap(tester, find.text('Create new trip'));
  for (final (i, value) in [
    'Synthetic trip',
    '2026-11-27',
    '2026-11-28',
    '8500.50',
    'Van',
    '3',
  ].indexed) {
    await enter(tester, i, value);
  }
  await tap(tester, find.text('Continue'));
}

void main() {
  final mapFinder = find.byType(GoogleMap);
  final openPicker = find.text('Pick on map');
  final confirm = find.widgetWithText(FilledButton, 'Confirm location');
  final useGps = find.text('Use current location');

  testWidgets(
    'confirmed pin survives Stop and Review navigation and sends only the stop name',
    (tester) async {
      _mockPickerMap(tester);
      final h = _Harness();
      h.mock((request) {
        if (request.method == ApiMethod.post) {
          expect(body(request)['initialStops'], [
            {'name': 'Map stop'},
            {'name': 'Manual stop'},
          ]);
          expect(body(request)['tripName'], 'Synthetic trip');
        }
        return _json(request.method == ApiMethod.post ? 201 : 200, _plan());
      });
      final picker = _PickerServices();
      await _openNewTripStops(tester, h, picker);
      await enter(tester, 0, 'Manual stop');
      await tap(tester, find.text('Add stop'));
      await enter(tester, 0, 'Map stop');
      await tap(tester, openPicker);
      expect(find.text('Pick a stop location'), findsOneWidget);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      for (final point in [const LatLng(7, 80), const LatLng(8, 81)]) {
        tester.widget<GoogleMap>(mapFinder).onTap!(point);
        await tester.pumpAndSettle();
        expect(
          tester.widget<GoogleMap>(mapFinder).markers.single.position,
          point,
        );
      }
      expect(find.text('Selected location 8.00000, 81.00000'), findsOneWidget);
      await tap(tester, confirm);
      expect(find.text('Map stop'), findsOneWidget);
      expect(find.text('Draft pin 8.00000, 81.00000'), findsOneWidget);
      expect(picker.permissionRequests, 0);

      await tap(tester, find.text('Add stop'));
      await tap(tester, find.byTooltip('Move Map stop up'));
      await tap(tester, find.text('Back to trip information'));
      expect(find.text('Synthetic trip'), findsOneWidget);
      await tap(tester, find.text('Continue'));
      await tap(tester, find.widgetWithText(FilledButton, 'Review trip'));
      expect(find.text('1. Map stop'), findsOneWidget);
      expect(find.text('2. Manual stop'), findsOneWidget);
      expect(find.text('Draft pin 8.00000, 81.00000'), findsOneWidget);
      expect(h.transport.requests.where((r) => r.uri.path == _base), isEmpty);
      await tap(tester, find.text('Save trip'));
      expect(find.text('Saved trip'), findsOneWidget);
    },
  );

  testWidgets(
    'Cancel and system Back discard picker changes and preserve the draft',
    (tester) async {
      _mockPickerMap(tester);
      final h = _Harness()
        ..mock(
          (request) => fail('Unexpected trip request: ${request.uri.path}'),
        );
      await _openNewTripStops(tester, h, _PickerServices());
      await enter(tester, 0, 'Manual stop');
      await tap(tester, find.text('Add stop'));
      await enter(tester, 0, 'Unadded stop');
      await tap(tester, openPicker);
      tester.widget<GoogleMap>(mapFinder).onTap!(const LatLng(7, 80));
      await tester.pumpAndSettle();
      await tap(tester, confirm);

      for (final systemBack in [false, true]) {
        await tap(tester, openPicker);
        expect(
          tester.widget<GoogleMap>(mapFinder).markers.single.position,
          const LatLng(7, 80),
        );
        tester.widget<GoogleMap>(mapFinder).onTap!(const LatLng(8, 81));
        await tester.pumpAndSettle();
        if (systemBack) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        } else {
          await tap(tester, find.text('Cancel'));
        }
        expect(find.text('Trip stops'), findsOneWidget);
        expect(find.text('Manual stop'), findsOneWidget);
        expect(find.text('Unadded stop'), findsOneWidget);
        expect(find.text('Draft pin 7.00000, 80.00000'), findsOneWidget);
        expect(find.textContaining('8.00000, 81.00000'), findsNothing);
      }
    },
  );

  testWidgets('GPS failures preserve a map pin and a granted fix replaces it', (
    tester,
  ) async {
    final map = _mockPickerMap(tester);
    final picker = _PickerServices();
    final h = _Harness()
      ..mock((request) => fail('Unexpected trip request: ${request.uri.path}'));
    await _openNewTripStops(tester, h, picker);
    await tap(tester, openPicker);
    const mapPin = LatLng(8, 81);
    tester.widget<GoogleMap>(mapFinder).onTap!(mapPin);
    await tester.pumpAndSettle();
    await tap(tester, useGps);
    expect(find.textContaining('Location permission denied'), findsOneWidget);
    expect(picker.permissionRequests, 1);
    expect(picker.reads, 0);
    picker.permission = DevicePermissionStatus.permanentlyDenied;
    await tap(tester, useGps);
    expect(find.textContaining('Allow Location for Wayhunter'), findsOneWidget);
    expect(picker.permissionRequests, 1);
    expect(picker.reads, 0);

    picker.permission = DevicePermissionStatus.denied;
    picker.requestResult = DevicePermissionStatus.granted;
    for (final (failure, message) in [
      (LocationFailure.serviceDisabled, 'Turn on Location'),
      (LocationFailure.timedOut, 'Location timed out'),
      (LocationFailure.unavailable, 'Could not get your location'),
    ]) {
      picker.failure = failure;
      await tap(tester, useGps);
      expect(find.textContaining(message), findsOneWidget);
      expect(
        tester.widget<GoogleMap>(mapFinder).markers.single.position,
        mapPin,
      );
    }
    picker.failure = null;
    await tap(tester, useGps);
    expect(map.cameraUpdates, hasLength(1));
    expect(
      tester.widget<GoogleMap>(mapFinder).markers.single.position,
      _PickerServices.fix,
    );
    await tap(tester, confirm);
    expect(find.text('Draft pin 6.90000, 79.80000'), findsOneWidget);
  });

  testWidgets('unconfigured or stalled Maps leaves manual stops usable', (
    tester,
  ) async {
    final map = _mockPickerMap(tester)..createsView = false;
    final picker = _PickerServices()..mapStatus = MapProviderStatus.unavailable;
    final h = _Harness()
      ..mock((request) => fail('Unexpected trip request: ${request.uri.path}'));
    await _openNewTripStops(tester, h, picker);
    await enter(tester, 0, 'Manual fallback');
    await tap(tester, openPicker);
    expect(find.textContaining('Google Maps is unavailable'), findsOneWidget);
    expect(mapFinder, findsNothing);
    await tap(tester, find.text('Cancel'));

    picker.mapStatus = MapProviderStatus.available;
    await tester.ensureVisible(openPicker);
    await tester.tap(openPicker);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(mapFinder, findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.textContaining('Google Maps is unavailable'), findsOneWidget);
    expect(mapFinder, findsNothing);
    expect(map.cameraUpdates, isEmpty);
    await tap(tester, find.text('Cancel'));
    await tap(tester, find.text('Add stop'));
    expect(find.text('Manual fallback'), findsOneWidget);
  });

  testWidgets('Traveller creates, reviews, saves and reopens an ordered plan', (
    tester,
  ) async {
    final h = _Harness();
    Map<String, Object?>? saved;
    h.mock((request) {
      if (request.method == ApiMethod.post) {
        expect(request.uri.path, _base);
        expect(body(request), {
          'tripName': 'Synthetic trip',
          'startDate': '2026-11-27',
          'endDate': '2026-11-28',
          'budgetLkr': 8500.50,
          'vehicleType': 'Van',
          'headcount': 3,
          'initialStops': [
            {'name': 'Second'},
            {'name': 'First'},
          ],
        });
        saved = _plan(
          stops: [_stop(_stopA, 'Second', 0), _stop(_stopB, 'First', 1)],
        );
        return _json(201, saved!);
      }
      if (request.uri.path == _base) return _json(200, [saved!]);
      expect(request.uri.path, '$_base/$_id');
      return _json(200, saved!);
    });
    await h.open(tester);
    await tap(tester, find.text('Create new trip'));
    await tap(tester, find.text('Continue'));
    expect(find.text('Enter a valid start date.'), findsOneWidget);
    expect(h.transport.requests.where((r) => r.uri.path == _base), isEmpty);
    for (final (i, value) in [
      'Synthetic trip',
      '2026-11-27',
      '2026-11-28',
      '8500.50',
      'Van',
      '3',
    ].indexed) {
      await enter(tester, i, value);
    }
    await tap(tester, find.text('Continue'));
    for (final name in ['First', 'Discard', 'Second']) {
      await enter(tester, 0, name);
      await tap(tester, find.text('Add stop'));
    }
    await tap(tester, find.byTooltip('Remove Discard'));
    await tap(tester, find.byTooltip('Move Second up'));
    await tap(tester, find.text('Back to trip information'));
    expect(find.text('Synthetic trip'), findsOneWidget);
    await tap(tester, find.text('Continue'));
    expect(find.text('Second'), findsOneWidget);
    await tap(tester, find.widgetWithText(FilledButton, 'Review trip'));
    await tap(tester, find.text('Save trip'));
    expect(find.text('Saved trip'), findsOneWidget);
    expect(find.text('Synthetic trip'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(tester, find.text('My Plans'));
    await tap(tester, find.text('Synthetic trip'));
    expect(find.text('Saved trip'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('My Plans shows loading, error, retry and empty state', (
    tester,
  ) async {
    final h = _Harness();
    final pending = Completer<TransportResponse>();
    h.mock((_) => pending.future);
    await h.open(tester);
    await tester.tap(find.text('My Plans'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(WayhunterLoadingView), findsOneWidget);
    pending.complete(const TransportResponse(503, []));
    await tester.pumpAndSettle();
    expect(find.text('Could not load trip plans'), findsOneWidget);
    h.mock((_) => _json(200, []));
    await tap(tester, find.text('Retry'));
    expect(find.text('No saved trips'), findsOneWidget);
  });

  testWidgets(
    'saved metadata edit and stop mutations carry latest server version',
    (tester) async {
      final h = _Harness();
      var saved = _plan(stops: [_stop(_stopA, 'First', 0)]);
      h.mock((request) {
        switch (request.method) {
          case ApiMethod.get:
            return _json(200, request.uri.path == _base ? [saved] : saved);
          case ApiMethod.post:
            expect(body(request), {
              'name': 'Second',
              'expectedRowVersion': _version,
            });
            saved = _plan(
              name: 'Edited trip',
              version: _nextVersion,
              stops: [_stop(_stopA, 'First', 0), _stop(_stopB, 'Second', 1)],
            );
          case ApiMethod.put:
            if (request.uri.path.endsWith('/order')) {
              expect(body(request), {
                'stopIds': [_stopB, _stopA],
                'expectedRowVersion': _nextVersion,
              });
              saved = _plan(
                name: 'Edited trip',
                version: _nextVersion,
                stops: [_stop(_stopA, 'First', 1), _stop(_stopB, 'Second', 0)],
              );
            } else {
              expect(body(request)['tripName'], 'Edited trip');
              expect(body(request)['expectedRowVersion'], _version);
              saved = _plan(
                name: 'Edited trip',
                stops: [_stop(_stopA, 'First', 0)],
              );
            }
          case ApiMethod.delete:
            fail('Versioned removal must not send a request without If-Match');
        }
        return _json(200, saved);
      });
      await h.open(tester);
      await tap(tester, find.text('My Plans'));
      await tap(tester, find.text('Synthetic trip'));
      await tap(tester, find.text('Edit trip information'));
      await enter(tester, 0, 'Edited trip');
      await tap(tester, find.text('Continue'));
      await tap(tester, find.text('Save trip'));
      expect(find.text('Edited trip'), findsOneWidget);
      await enter(tester, 0, 'Second');
      await tap(tester, find.text('Add stop'));
      await tap(tester, find.byTooltip('Move Second up'));
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Remove Second',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text(
          'Removing saved stops is unavailable for this versioned plan.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'stop conflict preserves input and reloads without repeating mutation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = _Harness();
      h.mock(
        (request) => switch (request.method) {
          ApiMethod.get => _json(
            200,
            request.uri.path == _base ? [_plan()] : _plan(),
          ),
          ApiMethod.post => _json(409, {
            'code': 'TRIP_PLAN_CONCURRENCY_CONFLICT',
          }),
          _ => fail('Unexpected request'),
        },
      );
      await h.open(tester);
      await tap(tester, find.text('My Plans'));
      await tap(tester, find.text('Synthetic trip'));
      await enter(tester, 0, 'Keep this stop');
      await tap(tester, find.text('Add stop'));
      expect(find.textContaining('Reload the plan'), findsOneWidget);
      await tap(tester, find.text('Reload saved plan'));
      expect(find.text('Keep this stop'), findsOneWidget);
      expect(
        h.transport.requests.where(
          (request) =>
              request.method == ApiMethod.get &&
              request.uri.path == '$_base/$_id',
        ),
        hasLength(2),
      );
      expect(
        h.transport.requests.where(
          (request) => request.method == ApiMethod.post,
        ),
        hasLength(1),
      );
    },
  );

  testWidgets('logout discards a pending private plan list', (tester) async {
    final h = _Harness();
    final pending = Completer<TransportResponse>();
    h.mock((_) => pending.future);
    await h.open(tester);
    await tester.tap(find.text('My Plans'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(tester, find.text('Profile'));
    await tap(tester, find.text('Sign out'));
    pending.complete(_json(200, [_plan()]));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic trip'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });

  test(
    'adapter rejects invalid ids, malformed data and unauthorized requests',
    () async {
      final h = _Harness();
      await h.session.authenticate(h.credential);
      final api = h.api;
      final expected = isA<ApiException>();
      await expectLater(
        api.get('../other-user'),
        throwsA(expected.having((e) => e.kind, 'kind', ApiError.notFound)),
      );
      expect(h.transport.requests, isEmpty);
      h.mock((_) => _json(200, {..._plan(), 'rowVersion': 'bad-version'}));
      await expectLater(
        api.get(_id),
        throwsA(
          expected.having((e) => e.kind, 'kind', ApiError.invalidResponse),
        ),
      );
      h.mock((_) => const TransportResponse(401, []));
      await expectLater(
        api.list(),
        throwsA(expected.having((e) => e.kind, 'kind', ApiError.unauthorized)),
      );
      await h.session.clear();
      await h.session.authenticate(
        const SessionCredential(
          user: UserRef('other-synthetic-user'),
          accessToken: 'other-synthetic-token',
        ),
      );
      await expectLater(
        api.list(),
        throwsA(expected.having((e) => e.kind, 'kind', ApiError.unauthorized)),
      );
      expect(h.transport.requests, hasLength(2));
      h.session.dispose();
    },
  );

  test(
    'unversioned remove and cancellation use the declared DELETE paths',
    () async {
      final h = _Harness();
      await h.session.authenticate(h.credential);
      h.mock((request) {
        expect(request.method, ApiMethod.delete);
        expect(request.body, isNull);
        expect(request.headers['If-Match'], isNull);
        return request.uri.path.endsWith('/$_stopA')
            ? _json(200, _plan(version: ''))
            : const TransportResponse(204, []);
      });
      final api = h.api;
      final plan = TripPlan.fromJson(
        _plan(version: '', stops: [_stop(_stopA, 'First', 0)]),
      );
      expect((await api.removeStop(plan, _stopA)).stops, isEmpty);
      await api.cancel(_id);
      expect(h.transport.requests.map((r) => r.uri.path), [
        '$_base/$_id/stops/$_stopA',
        '$_base/$_id',
      ]);
      h.session.dispose();
    },
  );
}
