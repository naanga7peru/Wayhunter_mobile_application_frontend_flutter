import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/services/device_interfaces.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/memories/data/trip_memories_api.dart';
import 'package:wayhunter_mobile/features/memories/domain/trip_memory.dart';
import 'package:wayhunter_mobile/features/memories/presentation/memories_screens.dart';
import 'package:wayhunter_mobile/features/safety/data/trip_hazards_api.dart';
import 'package:wayhunter_mobile/features/safety/domain/hazard_warning.dart';
import 'package:wayhunter_mobile/features/safety/presentation/safety_screens.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

const _owner = '51000000-0000-0000-0000-000000000001';
const _other = '51000000-0000-0000-0000-000000000002';
const _plan = '51000000-0000-0000-0000-000000000003';
const _hazard = '51000000-0000-0000-0000-000000000004';
const _memory = '51000000-0000-0000-0000-000000000005';
const _operation = '51000000-0000-0000-0000-000000000006';

TransportResponse _json(Object value, [int status = 200]) =>
    TransportResponse(status, utf8.encode(jsonEncode(value)));

Map<String, Object?> _warning({int status = 2}) => {
  'hazardId': _hazard,
  'status': status,
  'isVerified': status == 2,
  'latitude': 6.9271,
  'longitude': 79.8612,
  'description': 'Synthetic road hazard',
  'hasPhotoEvidence': true,
  'photoCapturedAtUtc': '2026-11-22T10:00:00Z',
  'reportedAtUtc': '2026-11-22T10:05:00Z',
  'expiresAtUtc': '2026-11-23T10:05:00Z',
  'verifiedAtUtc': status == 2 ? '2026-11-22T11:00:00Z' : null,
  'resolvedAtUtc': status == 3 ? '2026-11-22T12:00:00Z' : null,
};

Map<String, Object?> _memoryDto() => {
  'memoryId': _memory,
  'tripPlanId': _plan,
  'tripStopId': null,
  'caption': 'Synthetic memory',
  'visibility': 0,
  'createdAtUtc': '2026-11-22T10:00:00Z',
  'updatedAtUtc': '2026-11-22T10:00:00Z',
  'media': null,
};

class _Store implements CredentialStore {
  SessionCredential? value;
  @override
  Future<SessionCredential?> read() async => value;
  @override
  Future<void> write(SessionCredential credential) async => value = credential;
  @override
  Future<void> clear() async => value = null;
}

class _Transport implements HttpTransport {
  final requests = <TransportRequest>[];
  late Future<TransportResponse> Function(TransportRequest) respond;
  @override
  Future<TransportResponse> send(TransportRequest request) {
    requests.add(request);
    return respond(request);
  }
}

class _Harness {
  final store = _Store();
  final transport = _Transport();
  late final session = SessionController(store);
  late final client = ApiClient(
    baseUrl: Uri.https('example.invalid'),
    transport: transport,
    tokens: session,
  );

  Future<void> signIn([
    String owner = _owner,
    String token = 'synthetic-owner',
  ]) => session.authenticate(
    SessionCredential(user: UserRef(owner), accessToken: token),
  );
}

class _DeviceProbe
    implements DevicePermissions, CurrentLocation, LiveMediaCapture {
  int permissionChecks = 0;
  int permissionRequests = 0;
  int locationReads = 0;
  int cameraCaptures = 0;

  @override
  Future<DevicePermissionStatus> check(DevicePermission permission) async {
    permissionChecks++;
    return DevicePermissionStatus.unavailable;
  }

  @override
  Future<DevicePermissionStatus> request(DevicePermission permission) async {
    permissionRequests++;
    return DevicePermissionStatus.unavailable;
  }

  @override
  Future<LocationSample> read() async {
    locationReads++;
    throw const DeviceUnavailableException();
  }

  @override
  Future<LiveCapture> takePhoto() async {
    cameraCaptures++;
    throw const DeviceUnavailableException();
  }

  @override
  Future<LiveCapture> recordVideo() async =>
      throw const DeviceUnavailableException();
}

void main() {
  testWidgets(
    'memory retry keeps the original caption and operation after a lost response',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final h = _Harness();
      await h.signIn();
      h.transport.respond = (_) async => throw const TransportFailure();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripMemoryCreateScreen(
              plan: const TripPlanRef(_plan),
              api: TripMemoriesApi(h.client, h.session),
            ),
          ),
        ),
      );
      final caption = find.byType(TextFormField);
      await tester.enterText(caption, 'A quiet stop');
      final save = find.text('Save private memory');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(caption).controller!.text,
        'A quiet stop',
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).readOnly,
        isTrue,
      );
      final retry = find.text('Retry');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(h.transport.requests, hasLength(2));
      expect(h.transport.requests.last.body, h.transport.requests.first.body);
      expect(
        jsonDecode(h.transport.requests.last.body!)['caption'],
        'A quiet stop',
      );
    },
  );

  test(
    'hazard adapter maps authenticated route-scoped response and states',
    () async {
      final h = _Harness();
      await h.signIn();
      h.transport.respond = (_) async =>
          _json([_warning(), _warning(status: 1)]);

      final warnings = await TripHazardsApi(
        h.client,
        h.session,
      ).listForTrip(_plan);

      expect(warnings.map((warning) => warning.status), [
        HazardStatus.verified,
        HazardStatus.reported,
      ]);
      expect(warnings.first.photoCapturedAtUtc.isUtc, isTrue);
      expect(
        warnings.first.reportedAtUtc.toIso8601String(),
        '2026-11-22T10:05:00.000Z',
      );
      expect(h.transport.requests.single.method, ApiMethod.get);
      expect(
        h.transport.requests.single.uri.path,
        '/api/mobile/trips/$_plan/hazards',
      );
      expect(
        h.transport.requests.single.headers['Authorization'],
        'Bearer synthetic-owner',
      );
    },
  );

  test(
    'hazard malformed DTO, invalid trip ID and switched account fail closed',
    () async {
      final h = _Harness();
      await h.signIn();
      h.transport.respond = (_) async => _json([
        {'hazardId': 'bad'},
      ]);
      await expectLater(
        TripHazardsApi(h.client, h.session).listForTrip(_plan),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiError.invalidResponse,
          ),
        ),
      );
      await expectLater(
        TripHazardsApi(h.client, h.session).listForTrip('bad'),
        throwsA(
          isA<ApiException>().having((e) => e.kind, 'kind', ApiError.notFound),
        ),
      );
      final scoped = TripHazardsApi(h.client, h.session);
      await h.signIn(_other, 'synthetic-other');
      await expectLater(
        scoped.listForTrip(_plan),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiError.unauthorized,
          ),
        ),
      );
      expect(h.transport.requests, hasLength(1));
    },
  );

  test(
    'memory adapter sends source-defined private create body and maps CRUD DTOs',
    () async {
      final h = _Harness();
      await h.signIn();
      h.transport.respond = (request) async => switch (request.method) {
        ApiMethod.get when request.uri.path.endsWith('/memories') => _json([
          _memoryDto(),
        ]),
        ApiMethod.get => _json(_memoryDto()),
        ApiMethod.post => _json(_memoryDto(), 201),
        ApiMethod.delete => const TransportResponse(204, []),
        _ => fail('Unexpected request'),
      };
      final api = TripMemoriesApi(h.client, h.session);

      final listed = await api.list(_plan);
      final fetched = await api.get(_plan, _memory);
      final created = await api.create(
        _plan,
        operationId: _operation,
        caption: 'Synthetic memory',
      );
      await api.delete(_plan, _memory);

      expect(listed.single.visibility, TripMemoryVisibility.private);
      expect(fetched.id, _memory);
      expect(created.tripPlanId, _plan);
      final createRequest = h.transport.requests[2];
      expect(createRequest.method, ApiMethod.post);
      expect(createRequest.uri.path, '/api/mobile/trips/$_plan/memories');
      expect(jsonDecode(createRequest.body!), {
        'operationId': _operation,
        'tripStopId': null,
        'caption': 'Synthetic memory',
        'visibility': 0,
      });
      expect(h.transport.requests.last.method, ApiMethod.delete);
      expect(
        h.transport.requests.last.uri.path,
        '/api/mobile/trips/$_plan/memories/$_memory',
      );
    },
  );

  test(
    'memory unavailable, malformed DTO and account switch do not expose data',
    () async {
      final h = _Harness();
      await h.signIn();
      h.transport.respond = (_) async => const TransportResponse(503, []);
      final api = TripMemoriesApi(h.client, h.session);
      await expectLater(
        api.list(_plan),
        throwsA(
          isA<ApiException>().having((e) => e.kind, 'kind', ApiError.server),
        ),
      );
      h.transport.respond = (_) async => _json([
        {'memoryId': _memory},
      ]);
      await expectLater(
        api.list(_plan),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiError.invalidResponse,
          ),
        ),
      );
      final scoped = TripMemoriesApi(h.client, h.session);
      await h.signIn(_other, 'synthetic-other');
      await expectLater(
        scoped.list(_plan),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiError.unauthorized,
          ),
        ),
      );
    },
  );

  testWidgets(
    'empty hazards are not claimed safe and no device consent is requested',
    (tester) async {
      final h = _Harness();
      await h.signIn();
      h.transport.respond = (_) async => _json([]);
      final device = _DeviceProbe();
      await tester.pumpWidget(
        FoundationServices(
          api: h.client,
          session: h.session,
          permissions: device,
          location: device,
          capture: device,
          child: MaterialApp(
            home: TripSafetyScreen(
              plan: const TripPlanRef(_plan),
              api: TripHazardsApi(h.client, h.session),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('Route warnings cannot be confirmed'), findsOneWidget);
      expect(
        find.textContaining('not confirmation that the route has no hazards'),
        findsOneWidget,
      );
      expect(device.permissionChecks, 0);
      expect(device.permissionRequests, 0);
      expect(device.locationReads, 0);
      expect(device.cameraCaptures, 0);
    },
  );

  testWidgets('memories screen surfaces backend storage unavailable state', (
    tester,
  ) async {
    final h = _Harness();
    await h.signIn();
    h.transport.respond = (_) async => const TransportResponse(503, []);
    await tester.pumpWidget(
      MaterialApp(
        home: TripMemoriesScreen(
          plan: const TripPlanRef(_plan),
          api: TripMemoriesApi(h.client, h.session),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Memories unavailable'), findsOneWidget);
    expect(
      find.textContaining('private trip memory store is unavailable'),
      findsOneWidget,
    );
    expect(find.byType(WayhunterUnavailableView), findsOneWidget);
  });
}
