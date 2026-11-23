import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/data/trip_sessions_api.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

const _planId = '10000000-0000-0000-0000-000000000001';
const _sessionId = '10000000-0000-0000-0000-000000000002';
const _owner = '10000000-0000-0000-0000-000000000003';
const _other = '10000000-0000-0000-0000-000000000004';
const _planPath = '/api/mobile/trip-plans/$_planId';
const _startPath = '/api/mobile/trips/$_planId/sessions';
const _sessionPath = '$_startPath/$_sessionId';
const _args = ActiveTripArgs(
  plan: TripPlanRef(_planId),
  session: TripSessionRef(_sessionId),
);

TransportResponse _json(Object value) =>
    TransportResponse(200, utf8.encode(jsonEncode(value)));

Map<String, Object?> _session(int status) => {
  'tripPlanId': _planId,
  'sessionId': _sessionId,
  'status': status,
  'startedAtUtc': '2026-11-27T01:00:00+00:00',
  'finishedAtUtc': status == 3 ? '2026-11-27T03:00:00+00:00' : null,
};

Map<String, Object?> _plan() => {
  'tripPlanId': _planId,
  'tripName': 'Synthetic live trip',
  'startDate': '2026-11-27',
  'endDate': '2026-11-28',
  'budgetLkr': 6000,
  'vehicleType': 'Van',
  'headcount': 2,
  'rowVersion': 'AAAAAAAAAAE=',
  'stops': [],
};

class _Store implements CredentialStore {
  SessionCredential? data = const SessionCredential(
    user: UserRef(_owner),
    accessToken: 'synthetic-session-owner',
  );
  @override
  Future<SessionCredential?> read() async => data;
  @override
  Future<void> write(SessionCredential credential) async => data = credential;
  @override
  Future<void> clear() async => data = null;
}

class _Transport implements HttpTransport {
  final requests = <TransportRequest>[];
  late FutureOr<TransportResponse> Function(TransportRequest) handle;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return handle(request);
  }
}

class _Harness {
  final transport = _Transport();
  final store = _Store();
  late final session = SessionController(store);
  late final api = ApiClient(
    baseUrl: Uri.https('example.invalid'),
    tokens: session,
    transport: transport,
    timeout: const Duration(seconds: 1),
  );

  void mock(FutureOr<TransportResponse> Function(TransportRequest) respond) {
    transport.handle = (request) => switch (request.uri.path) {
      '/api/mobile/identity/me' => _json({
        'userId':
            request.headers['Authorization'] == 'Bearer synthetic-other-account'
            ? _other
            : _owner,
        'displayName': 'Synthetic visitor',
        'email': 'visitor@example.invalid',
      }),
      '/api/mobile/advertisements/active' => _json([]),
      '/api/mobile/auth/logout' => const TransportResponse(204, []),
      '/api/mobile/identity/login' => _json({
        'userId': _other,
        'accessToken': 'synthetic-other-account',
        'expiresAtUtc': '2099-01-01T00:00:00Z',
      }),
      _planPath =>
        request.headers['Authorization'] == 'Bearer synthetic-session-owner'
            ? _json(_plan())
            : const TransportResponse(404, []),
      _ => respond(request),
    };
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      FoundationServices(
        api: api,
        session: session,
        child: const WayhunterApp.authenticated(apiConfigured: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<TransportRequest> get lifecycle => transport.requests
      .where((r) => r.uri.path.startsWith(_startPath))
      .toList();
}

NavigatorState _navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator));

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _openPlan(WidgetTester tester) async {
  unawaited(
    _navigator(tester).pushNamed<void>(
      AppRoutes.tripPlan,
      arguments: const TripPlanRef(_planId),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openActive(
  WidgetTester tester, [
  ActiveTripArgs args = _args,
]) async {
  unawaited(
    _navigator(tester).pushNamed<void>(AppRoutes.activeTrip, arguments: args),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'saved trip starts once, recovers, pauses, resumes and completes from server DTO',
    (tester) async {
      final h = _Harness();
      final created = Completer<TransportResponse>();
      h.mock((request) {
        expect(
          request.headers['Authorization'],
          'Bearer synthetic-session-owner',
        );
        expect(request.body, isNull);
        expect(
          request.method,
          request.uri.path.endsWith('/recover')
              ? ApiMethod.get
              : ApiMethod.post,
        );
        return switch (request.uri.path) {
          _startPath => created.future,
          '$_sessionPath/recover' ||
          '$_sessionPath/resume' => _json(_session(1)),
          '$_sessionPath/pause' => _json(_session(2)),
          '$_sessionPath/finish' => _json(_session(3)),
          _ => fail('Unexpected path: ${request.uri.path}'),
        };
      });
      await h.open(tester);
      await _openPlan(tester);
      final start = find.widgetWithText(FilledButton, 'Start trip');
      await tester.tap(start);
      await tester.tap(start);
      await tester.pump();
      expect(h.lifecycle, hasLength(1));
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      created.complete(_json(_session(1)));
      await tester.pumpAndSettle();
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Started 2026-11-27T01:00:00.000Z'), findsOneWidget);
      expect(h.lifecycle.last.uri.path, '$_sessionPath/recover');

      await _tap(tester, 'Pause trip');
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Pause trip'), findsNothing);
      await _tap(tester, 'Resume trip');
      expect(find.text('Active'), findsOneWidget);
      await _tap(tester, 'Recover session');
      expect(h.lifecycle.last.method, ApiMethod.get);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'Open trip session');
      expect(h.lifecycle.last.uri.path, '$_sessionPath/recover');
      expect(h.lifecycle.where((r) => r.uri.path == _startPath), hasLength(1));

      await _tap(tester, 'Finish trip');
      expect(find.text('Completed trip'), findsOneWidget);
      expect(find.text('Finished 2026-11-27T03:00:00.000Z'), findsOneWidget);
      expect(find.text('Finish trip'), findsNothing);
      await _tap(tester, 'Back to saved trip');
      await _tap(tester, 'View completed trip');
      expect(find.text('Completed trip'), findsOneWidget);
      expect(h.lifecycle.last.uri.path, '$_sessionPath/finish');
    },
  );

  testWidgets(
    'action conflict recovers current status and duplicate taps send one mutation',
    (tester) async {
      final h = _Harness();
      final pending = Completer<TransportResponse>();
      var recoveries = 0;
      h.mock(
        (request) => switch (request.uri.path) {
          '$_sessionPath/recover' => _json(_session(++recoveries == 1 ? 1 : 2)),
          '$_sessionPath/pause' => pending.future,
          _ => fail('Unexpected route'),
        },
      );
      await h.open(tester);
      await _openActive(tester);
      final pause = find.widgetWithText(FilledButton, 'Pause trip');
      await tester.tap(pause);
      await tester.tap(pause);
      await tester.pump();
      expect(tester.widget<FilledButton>(pause).onPressed, isNull);
      pending.complete(const TransportResponse(409, []));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);
      expect(
        find.text('Current session status recovered from the server.'),
        findsOneWidget,
      );
      expect(h.lifecycle.map((r) => r.uri.path), [
        '$_sessionPath/recover',
        '$_sessionPath/pause',
        '$_sessionPath/recover',
      ]);
    },
  );

  testWidgets(
    'timed-out Finish with recovery 404 never reports completion or replays',
    (tester) async {
      final h = _Harness();
      final pending = Completer<TransportResponse>();
      var recoveries = 0;
      h.mock(
        (request) => switch (request.uri.path) {
          '$_sessionPath/recover' =>
            ++recoveries == 1
                ? _json(_session(2))
                : const TransportResponse(404, []),
          '$_sessionPath/finish' => pending.future,
          _ => fail('Unexpected route'),
        },
      );
      await h.open(tester);
      await _openActive(tester);
      expect(find.text('Paused'), findsOneWidget);
      await tester.tap(find.text('Finish trip'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Trip session unavailable'), findsOneWidget);
      expect(find.text('Completed trip'), findsNothing);
      expect(find.text('Finish trip'), findsNothing);
      await _tap(tester, 'Retry');
      expect(
        h.lifecycle.where((r) => r.uri.path.endsWith('/finish')),
        hasLength(1),
      );
      pending.complete(_json(_session(3)));
    },
  );

  testWidgets(
    'unconfirmed Start stays blocked when saved details are reopened',
    (tester) async {
      final h = _Harness();
      h.mock((request) {
        expect(request.uri.path, _startPath);
        throw const TransportFailure();
      });
      await h.open(tester);
      await _openPlan(tester);
      await _tap(tester, 'Start trip');
      expect(
        find.textContaining('Recovery requires a session ID'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start trip'),
            )
            .onPressed,
        isNull,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _openPlan(tester);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start trip'),
            )
            .onPressed,
        isNull,
      );
      expect(h.lifecycle, hasLength(1));
    },
  );

  for (final (code, message) in [
    (401, 'Your sign-in session expired or is no longer authorized.'),
    (403, 'Your account cannot access this trip session.'),
    (
      503,
      'The trip service is unavailable. Try recovering when it is back online.',
    ),
  ]) {
    testWidgets('recovery HTTP $code keeps actions hidden and supports retry', (
      tester,
    ) async {
      final h = _Harness();
      h.mock((_) => TransportResponse(code, const []));
      await h.open(tester);
      await _openActive(tester);
      expect(find.text(message), findsOneWidget);
      expect(find.text('Pause trip'), findsNothing);
      h.mock((_) => _json(_session(1)));
      await _tap(tester, 'Retry');
      expect(find.text('Active'), findsOneWidget);
    });
  }

  testWidgets(
    'invalid route IDs are rejected and account switch cannot recover a private trip',
    (tester) async {
      final h = _Harness();
      h.mock((_) => _json(_session(1)));
      await h.open(tester);
      await _openActive(
        tester,
        const ActiveTripArgs(
          plan: TripPlanRef(_planId),
          session: TripSessionRef('bad-id'),
        ),
      );
      expect(h.lifecycle, isEmpty);
      expect(find.text('Active trip'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _openActive(tester);
      expect(find.text('Synthetic live trip'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'Profile');
      await _tap(tester, 'Wallet');
      expect(find.text('Wallet balance unavailable'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'Sign out');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'other@example.invalid');
      await tester.enterText(fields.last, 'SyntheticPassword42');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();
      await _openActive(tester);
      expect(find.text('Trip session unavailable'), findsOneWidget);
      expect(find.text('Synthetic live trip'), findsNothing);
      expect(h.lifecycle, hasLength(1));
    },
  );

  test(
    'rejects malformed/mismatched DTOs and drops late private responses after clearing',
    () async {
      final h = _Harness();
      await h.session.restore();
      final api = TripSessionsApi(h.api, h.session);
      final invalid = isA<ApiException>().having(
        (e) => e.kind,
        'kind',
        ApiError.invalidResponse,
      );
      h.mock((_) => _json({..._session(1), 'sessionId': _other}));
      await expectLater(api.recover(_args), throwsA(invalid));
      h.mock((_) => _json({..._session(3), 'finishedAtUtc': null}));
      await expectLater(api.recover(_args), throwsA(invalid));
      final pending = Completer<TransportResponse>();
      h.mock((_) => pending.future);
      final response = api.recover(_args);
      final assertion = expectLater(
        response,
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiError.unauthorized,
          ),
        ),
      );
      await h.session.clear();
      pending.complete(_json(_session(1)));
      await assertion;
      expect(api.known(_args.plan), isNull);
      h.session.dispose();
    },
  );
}
