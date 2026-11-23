import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
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

  Future<void> open(WidgetTester tester) async {
    store.value = credential;
    await tester.pumpWidget(
      FoundationServices(
        api: client,
        session: session,
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

void main() {
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
