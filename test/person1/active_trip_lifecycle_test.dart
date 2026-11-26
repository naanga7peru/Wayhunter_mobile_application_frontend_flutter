import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/data/trip_recovery_store.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/data/trip_sessions_api.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/domain/trip_session.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

import 'wallet_balance_fixture.dart';

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

class _RecoveryStore implements TripRecoveryStore {
  final values = <(String, String), String>{};
  bool failWrites = false;
  bool failDeletes = false;
  bool deleteBeforeFailure = false;
  Future<void>? pendingDelete;
  void Function()? onDelete;

  @override
  Future<String?> read(String owner, String trip) async =>
      values[(owner, trip)];

  @override
  Future<void> write(String owner, String trip, String? pending) async {
    if (pending == null) {
      if (failDeletes && !deleteBeforeFailure) {
        throw const ApiException(ApiError.unavailable);
      }
      values.remove((owner, trip));
      onDelete?.call();
      await pendingDelete;
      if (failDeletes) throw const ApiException(ApiError.unavailable);
    } else {
      if (failWrites) throw const ApiException(ApiError.unavailable);
      values[(owner, trip)] = pending;
    }
  }
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
  _Harness({
    this.notifyUnauthorized = false,
    this.timeout = const Duration(seconds: 1),
  });

  final bool notifyUnauthorized;
  final Duration timeout;
  final transport = _Transport();
  final store = _Store();
  late final session = SessionController(store);
  late final api = ApiClient(
    baseUrl: Uri.https('example.invalid'),
    tokens: session,
    transport: transport,
    timeout: timeout,
    captureUnauthorizedHandler: notifyUnauthorized
        ? session.captureUnauthorizedHandler
        : null,
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
      walletBalancePath => walletBalanceResponse(),
      '/api/mobile/auth/logout' => const TransportResponse(204, []),
      '/api/mobile/identity/login' => _loginResponse(request),
      _planPath =>
        request.headers['Authorization'] == 'Bearer synthetic-session-owner'
            ? _json(_plan())
            : const TransportResponse(404, []),
      _ => respond(request),
    };
  }

  TransportResponse _loginResponse(TransportRequest request) {
    final sameOwner =
        jsonDecode(request.body!)['email'] == 'visitor@example.invalid';
    return _json({
      'userId': sameOwner ? _owner : _other,
      'accessToken': sameOwner
          ? 'synthetic-session-owner'
          : 'synthetic-other-account',
      'expiresAtUtc': '2099-01-01T00:00:00Z',
    });
  }

  Future<void> open(
    WidgetTester tester, {
    TripRecoveryStore? recoveryStore,
  }) async {
    await tester.pumpWidget(
      FoundationServices(
        api: api,
        session: session,
        tripRecovery: recoveryStore,
        child: const WayhunterApp.authenticated(apiConfigured: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<TransportRequest> get lifecycle => transport.requests
      .where((r) => r.uri.path.startsWith(_startPath))
      .toList();
}

Matcher _apiError(ApiError kind) =>
    isA<ApiException>().having((error) => error.kind, 'kind', kind);

const _ownerCredential = SessionCredential(
  user: UserRef(_owner),
  accessToken: 'synthetic-session-owner',
);
const _otherCredential = SessionCredential(
  user: UserRef(_other),
  accessToken: 'synthetic-other-account',
);

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
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Start 401 expires the session and the same owner can start after signing in',
    (tester) async {
      final h = _Harness(notifyUnauthorized: true);
      final store = _RecoveryStore();
      var attempts = 0;
      h.mock((request) {
        if (request.uri.path == '$_sessionPath/recover') {
          return _json(_session(1));
        }
        expect(request.uri.path, _startPath);
        expect(request.method, ApiMethod.post);
        expect(store.values[(_owner, _planId)], pendingTripStart);
        return ++attempts == 1
            ? const TransportResponse(401, [])
            : _json(_session(1));
      });
      await h.open(tester, recoveryStore: store);
      await _openPlan(tester);
      await _tap(tester, 'Start trip');
      expect(find.text('Your session ended. Sign in again.'), findsOneWidget);
      expect(h.session.state.status, SessionStatus.expired);
      expect(h.store.data, isNull);
      expect(store.values, isEmpty);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'visitor@example.invalid');
      await tester.enterText(fields.last, 'SyntheticPass42');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();
      expect(h.session.state.user?.id, _owner);
      await _openPlan(tester);
      expect(find.text('Recover with session ID'), findsNothing);
      await _tap(tester, 'Start trip');
      expect(find.text('Active trip'), findsOneWidget);
      expect(attempts, 2);
    },
  );

  test(
    'Finish 403 clears its marker after a definite owner rejection',
    () async {
      final h = _Harness(notifyUnauthorized: true);
      await h.session.restore();
      final store = _RecoveryStore();
      final api = TripSessionsApi(h.api, h.session, recoveryStore: store);
      h.mock((request) {
        expect(request.uri.path, '$_sessionPath/finish');
        expect(store.values[(_owner, _planId)], _sessionId);
        return const TransportResponse(403, []);
      });
      await expectLater(
        api.change(_args, TripSessionAction.finish),
        throwsA(_apiError(ApiError.forbidden)),
      );
      expect(h.session.state.status, SessionStatus.authenticated);
      expect(store.values, isEmpty);
      expect(api.finishNeedsVerification(_args.plan), isFalse);
      final replacement = TripSessionsApi(
        h.api,
        h.session,
        recoveryStore: store,
      );
      await replacement.loadRecovery(_args.plan);
      expect(replacement.finishNeedsVerification(_args.plan), isFalse);
    },
  );

  test(
    'Start keeps its marker for conflict, server failure and an invalid receipt',
    () async {
      for (final (response, kind) in [
        (const TransportResponse(409, []), ApiError.conflict),
        (const TransportResponse(503, []), ApiError.server),
        (_json({'sessionId': _sessionId}), ApiError.invalidResponse),
      ]) {
        final h = _Harness();
        await h.session.restore();
        final store = _RecoveryStore();
        h.mock((_) => response);
        final api = TripSessionsApi(h.api, h.session, recoveryStore: store);
        await expectLater(api.start(_args.plan), throwsA(_apiError(kind)));
        expect(store.values, {(_owner, _planId): pendingTripStart});
      }
    },
  );

  test(
    'Start timeout retains the marker in the secure-storage adapter',
    () async {
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final values = <String, String>{};
      messenger.setMockMethodCallHandler(channel, (call) async {
        final key = call.arguments['key'] as String;
        switch (call.method) {
          case 'read':
            return values[key];
          case 'write':
            values[key] = call.arguments['value'] as String;
            return null;
          default:
            fail('Unexpected secure storage operation');
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final h = _Harness(timeout: const Duration(milliseconds: 20));
      await h.session.restore();
      const store = SecureTripRecoveryStore('trip-timeout-fixture');
      final pending = Completer<TransportResponse>();
      h.mock((_) => pending.future);
      final api = TripSessionsApi(h.api, h.session, recoveryStore: store);
      await expectLater(
        api.start(_args.plan),
        throwsA(_apiError(ApiError.timeout)),
      );
      expect(values.values, [pendingTripStart]);
      final replacement = TripSessionsApi(
        h.api,
        h.session,
        recoveryStore: store,
      );
      await expectLater(
        replacement.start(_args.plan),
        throwsA(_apiError(ApiError.conflict)),
      );
      expect(h.lifecycle, hasLength(1));
      pending.complete(const TransportResponse(401, []));
      expect(values.values, [pendingTripStart]);
    },
  );

  test(
    'a delayed trip 401 clears only the dispatching owner’s marker',
    () async {
      final h = _Harness(notifyUnauthorized: true);
      await h.session.restore();
      final store = _RecoveryStore();
      final dispatched = Completer<void>();
      final response = Completer<TransportResponse>();
      h.mock((request) {
        if (request.headers['Authorization'] ==
            'Bearer synthetic-session-owner') {
          dispatched.complete();
          return response.future;
        }
        throw const TransportFailure();
      });
      final first = TripSessionsApi(h.api, h.session, recoveryStore: store);
      final rejected = expectLater(
        first.start(_args.plan),
        throwsA(_apiError(ApiError.unauthorized)),
      );
      await dispatched.future;
      await h.session.authenticate(_otherCredential);
      final second = TripSessionsApi(h.api, h.session, recoveryStore: store);
      await expectLater(
        second.start(_args.plan),
        throwsA(_apiError(ApiError.network)),
      );
      response.complete(const TransportResponse(401, []));
      await rejected;
      expect(store.values, {(_other, _planId): pendingTripStart});
      expect(h.session.currentSessionRejected, isFalse);
      expect(h.session.state.user?.id, _other);
    },
  );

  test(
    'same-owner replacement cannot reconcile or write during older cleanup',
    () async {
      final h = _Harness(notifyUnauthorized: true);
      await h.session.restore();
      final store = _RecoveryStore();
      final rejectedResponse = Completer<TransportResponse>();
      final dispatched = Completer<void>();
      final cleanup = Completer<void>();
      final deleting = Completer<void>();
      store
        ..pendingDelete = cleanup.future
        ..onDelete = deleting.complete;
      h.mock((_) {
        dispatched.complete();
        return rejectedResponse.future;
      });
      final old = TripSessionsApi(h.api, h.session, recoveryStore: store);
      final rejected = expectLater(
        old.start(_args.plan),
        throwsA(_apiError(ApiError.unauthorized)),
      );
      await dispatched.future;
      await h.session.authenticate(_ownerCredential);
      rejectedResponse.complete(const TransportResponse(401, []));
      // Wait until the fake delete takes effect but has not yet acknowledged it.
      await deleting.future;
      expect(store.values, isEmpty);

      final replacement = TripSessionsApi(
        h.api,
        h.session,
        recoveryStore: store,
      );
      await expectLater(
        replacement.recover(_args),
        throwsA(_apiError(ApiError.conflict)),
      );
      await expectLater(
        replacement.start(_args.plan),
        throwsA(_apiError(ApiError.conflict)),
      );
      expect(h.lifecycle, hasLength(1));
      cleanup.complete();
      await rejected;

      h.mock((_) => throw const TransportFailure());
      await expectLater(
        replacement.start(_args.plan),
        throwsA(_apiError(ApiError.network)),
      );
      expect(store.values, {(_owner, _planId): pendingTripStart});
      expect(h.session.currentSessionRejected, isFalse);
      expect(h.lifecycle, hasLength(2));
    },
  );

  for (final deleteBeforeFailure in [false, true]) {
    test(
      'failed cleanup blocks a replacement adapter (delete took effect: $deleteBeforeFailure)',
      () async {
        final h = _Harness(notifyUnauthorized: true);
        await h.session.restore();
        final store = _RecoveryStore()
          ..deleteBeforeFailure = deleteBeforeFailure;
        h.mock((_) {
          store.failDeletes = true;
          store.failWrites = true;
          return const TransportResponse(401, []);
        });
        final api = TripSessionsApi(h.api, h.session, recoveryStore: store);
        await expectLater(
          api.start(_args.plan),
          throwsA(_apiError(ApiError.unavailable)),
        );
        expect(
          store.values[(_owner, _planId)],
          deleteBeforeFailure ? null : pendingTripStart,
        );
        await h.session.authenticate(_ownerCredential);
        final replacement = TripSessionsApi(
          h.api,
          h.session,
          recoveryStore: store,
        );
        await replacement.loadRecovery(_args.plan);
        expect(replacement.startNeedsVerification(_args.plan), isTrue);
        await expectLater(
          replacement.start(_args.plan),
          throwsA(_apiError(ApiError.conflict)),
        );
        expect(h.lifecycle, hasLength(1));
      },
    );
  }

  test(
    'an unconfirmed Start on disk blocks another Start until a verified GET',
    () async {
      final h = _Harness();
      await h.session.restore();
      final store = _RecoveryStore();
      TripSessionsApi api() =>
          TripSessionsApi(h.api, h.session, recoveryStore: store);
      final conflict = isA<ApiException>().having(
        (e) => e.kind,
        'kind',
        ApiError.conflict,
      );
      store.failWrites = true;
      await expectLater(api().start(_args.plan), throwsA(isA<ApiException>()));
      expect(h.lifecycle, isEmpty);
      store.failWrites = false;
      h.mock((request) {
        expect(request.uri.path, _startPath);
        expect(store.values[(_owner, _planId)], pendingTripStart);
        throw const TransportFailure();
      });
      await expectLater(api().start(_args.plan), throwsA(isA<ApiException>()));
      final relaunched = api();
      await expectLater(relaunched.open(_args.plan), throwsA(conflict));
      expect(relaunched.startNeedsVerification(_args.plan), isTrue);
      h.mock((request) {
        expect(request.method, ApiMethod.get);
        expect(request.uri.path, '$_sessionPath/recover');
        return _json(_session(1));
      });
      expect(
        (await relaunched.recover(_args)).status,
        TripSessionStatus.active,
      );
      expect((await relaunched.open(_args.plan)).session.id, _sessionId);
      expect(store.values, isEmpty);
      expect(h.lifecycle.map((r) => r.method), [ApiMethod.post, ApiMethod.get]);
    },
  );

  test(
    'a lost Finish persists its ID and a recovery 404 keeps mutations blocked',
    () async {
      final h = _Harness();
      await h.session.restore();
      final store = _RecoveryStore();
      TripSessionsApi api() =>
          TripSessionsApi(h.api, h.session, recoveryStore: store);
      final active = api();
      h.mock((request) {
        if (request.method == ApiMethod.get) {
          return const TransportResponse(404, []);
        }
        expect(store.values[(_owner, _planId)], _sessionId);
        throw const TransportFailure();
      });
      await expectLater(
        active.change(_args, TripSessionAction.finish),
        throwsA(isA<ApiException>()),
      );
      final relaunched = api();
      expect((await relaunched.open(_args.plan)).session.id, _sessionId);
      await expectLater(
        relaunched.recover(_args),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        relaunched.change(_args, TripSessionAction.finish),
        throwsA(isA<ApiException>()),
      );
      expect(store.values[(_owner, _planId)], _sessionId);
      expect(h.lifecycle.map((r) => r.method), [ApiMethod.post, ApiMethod.get]);
    },
  );

  testWidgets(
    'Safe Check-in retries a lost receipt and confirms the same logical check-in',
    (tester) async {
      final h = _Harness();
      var checks = 0;
      h.mock((request) {
        if (request.uri.path == '$_sessionPath/recover') {
          return _json(_session(1));
        }
        expect(request.uri.path, '$_sessionPath/im-safe');
        expect(request.method, ApiMethod.post);
        expect(request.body, isNull);
        expect(
          request.headers['Authorization'],
          'Bearer synthetic-session-owner',
        );
        if (++checks == 1) throw const TransportFailure();
        return _json({
          'checkInId': _other,
          'tripPlanId': _planId,
          'sessionId': _sessionId,
          'userId': _owner,
          'checkedInAtUtc': '2026-11-27T02:00:00Z',
          'created': false,
        });
      });
      await h.open(tester);
      await _openActive(tester);
      await _tap(tester, 'I’m Safe');
      expect(
        find.textContaining('Check-in could not be confirmed'),
        findsOneWidget,
      );
      await _tap(tester, 'I’m Safe');
      expect(find.textContaining('Safe check-in recorded'), findsOneWidget);
      expect(find.text('I’m Safe'), findsNothing);
      expect(checks, 2);
    },
  );

  testWidgets(
    'saved trip reads its own route-matched hazards before starting',
    (tester) async {
      final h = _Harness();
      h.mock((request) {
        expect(request.method, ApiMethod.get);
        expect(request.uri.path, '/api/mobile/trips/$_planId/hazards');
        return _json([
          {
            'hazardId': _other,
            'status': 1,
            'isVerified': false,
            'hasPhotoEvidence': true,
            'photoCapturedAtUtc': '2025-11-27T01:00:00Z',
            'reportedAtUtc': '2025-11-27T02:00:00Z',
            'expiresAtUtc': '2025-11-28T02:00:00Z',
            'description': 'Expired test warning',
          },
        ]);
      });
      await h.open(tester);
      await _openPlan(tester);
      await _tap(tester, 'Trip safety');
      expect(find.text('Route warnings cannot be confirmed'), findsOneWidget);
      expect(find.text('Expired test warning'), findsNothing);
      expect(h.lifecycle, isEmpty);
    },
  );

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
    'confirmed completion opens authenticated memories for its trip',
    (tester) async {
      final h = _Harness();
      const memoriesPath = '/api/mobile/trips/$_planId/memories';
      h.mock((request) {
        if (request.uri.path == memoriesPath) {
          expect(request.method, ApiMethod.get);
          expect(
            request.headers['Authorization'],
            'Bearer synthetic-session-owner',
          );
          return _json([]);
        }
        return switch (request.uri.path) {
          '$_sessionPath/recover' => _json(_session(1)),
          '$_sessionPath/finish' => _json(_session(3)),
          _ => fail('Unexpected path: ${request.uri.path}'),
        };
      });
      await h.open(tester);
      await _openActive(tester);
      await _tap(tester, 'Finish trip');
      expect(find.text('Completed trip'), findsOneWidget);

      await _tap(tester, 'Trip memories');
      expect(find.text('No saved memories'), findsOneWidget);
      expect(
        h.transport.requests.where((r) => r.uri.path == memoriesPath),
        hasLength(1),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Completed trip'), findsOneWidget);
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
      expect(find.text('Trip memories'), findsNothing);
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
      expect(find.text('$fixtureSpendableCoins'), findsOneWidget);
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
