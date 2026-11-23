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
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/friends/data/trip_invitations_api.dart';
import 'package:wayhunter_mobile/features/friends/domain/trip_invitation.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

import 'wallet_balance_fixture.dart';

const _owner = '40000000-0000-0000-0000-000000000001';
const _other = '40000000-0000-0000-0000-000000000002';
const _plan = '40000000-0000-0000-0000-000000000003';
const _invite = '40000000-0000-0000-0000-000000000004';
const _member = '40000000-0000-0000-0000-000000000005';
const _base = '/api/mobile/trip-invitations';
const _send = '/api/mobile/trips/$_plan/invitations';

TransportResponse _json(Object value, [int code = 200]) =>
    TransportResponse(code, utf8.encode(jsonEncode(value)));
Map<String, Object?> _invitation({bool outgoing = false}) => {
  'invitationId': _invite,
  'tripPlanId': _plan,
  'senderUserId': outgoing ? _owner : _other,
  'recipientUserId': outgoing ? _other : _owner,
  'status': 0,
  'createdAtUtc': '2026-11-23T00:00:00+00:00',
};
Map<String, Object?> _decision(int status) => {
  'invitationId': _invite,
  'status': status,
  'memberId': status == 1 ? _member : null,
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
  late FutureOr<TransportResponse> Function(TransportRequest) respond;
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return respond(request);
  }
}

class _Harness {
  static const credential = SessionCredential(
    user: UserRef(_owner),
    accessToken: 'synthetic-first',
  );
  final store = _Store();
  final transport = _Transport();
  late final session = SessionController(store);
  late final client = ApiClient(
    baseUrl: Uri.https('example.invalid'),
    transport: transport,
    tokens: session,
  );
  TripInvitationsApi get api => TripInvitationsApi(client, session);

  void mock(FutureOr<TransportResponse> Function(TransportRequest) handle) {
    transport.respond = (request) {
      final other =
          request.headers['Authorization'] == 'Bearer synthetic-second';
      return switch (request.uri.path) {
        '/api/mobile/identity/me' => _json({
          'userId': other ? _other : _owner,
          'displayName': 'Synthetic visitor',
          'email': 'visitor@example.invalid',
        }),
        '/api/mobile/advertisements/active' => _json([]),
        walletBalancePath => walletBalanceResponse(),
        '/api/mobile/auth/logout' => const TransportResponse(204, []),
        '/api/mobile/identity/login' => _json({
          'userId': _other,
          'accessToken': 'synthetic-second',
          'expiresAtUtc': '2099-01-01T00:00:00Z',
        }),
        '/api/mobile/trip-plans/$_plan' => _json({
          'tripPlanId': _plan,
          'tripName': 'Saved synthetic trip',
          'startDate': '2099-01-01',
          'endDate': '2099-01-02',
          'budgetLkr': 1000,
          'vehicleType': 'Van',
          'headcount': 2,
          'stops': [],
          'rowVersion': 'AAAAAAAAAAE=',
        }),
        _ => handle(request),
      };
    };
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    store.value = credential;
    await tester.pumpWidget(
      FoundationServices(
        api: client,
        session: session,
        child: const WayhunterApp.authenticated(apiConfigured: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSavedTrip(WidgetTester tester) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.pushNamed<void>(
        AppRoutes.tripPlan,
        arguments: const TripPlanRef(_plan),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _profile(WidgetTester tester) => _tap(tester, 'Profile');

void main() {
  testWidgets(
    'Profile opens Friends with loading, unavailable, and empty states',
    (tester) async {
      final h = _Harness();
      final pending = Completer<TransportResponse>();
      h.mock((_) => pending.future);
      await h.open(tester);
      await _profile(tester);
      await _tap(tester, 'Wallet');
      expect(find.text('$fixtureSpendableCoins'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Friends'));
      await tester.tap(find.text('Friends'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(WayhunterLoadingView), findsOneWidget);
      pending.complete(const TransportResponse(503, []));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('unavailable from the server'),
        findsOneWidget,
      );
      h.mock((_) => _json([]));
      await _tap(tester, 'Retry');
      expect(find.text('No pending trip invitations'), findsOneWidget);
      expect(find.textContaining('contact discovery'), findsOneWidget);
    },
  );

  testWidgets('draft Add Friends preserves unsaved trip information on Back', (
    tester,
  ) async {
    final h = _Harness()..mock((_) => _json([]));
    await h.open(tester);
    await _tap(tester, 'Traveler');
    await _tap(tester, 'Create new trip');
    await tester.enterText(
      find.byType(TextFormField).first,
      'Unsaved test draft',
    );
    await _tap(tester, 'Add Friends');
    expect(find.textContaining('from a saved trip'), findsOneWidget);
    expect(find.text('Send invitation'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Unsaved test draft'), findsOneWidget);
  });

  testWidgets(
    'saved trip can send once and cancel a confirmed outgoing invitation',
    (tester) async {
      final h = _Harness();
      final pending = Completer<TransportResponse>();
      h.mock(
        (request) => switch (request.uri.path) {
          '$_base/pending' => _json([]),
          _send => pending.future,
          '$_base/$_invite/cancel' => _json(_decision(3)),
          _ => fail('Unexpected request'),
        },
      );
      await h.open(tester);
      await h.openSavedTrip(tester);
      await _tap(tester, 'Add Friends');
      await _tap(tester, 'Send invitation');
      expect(find.textContaining('another Wayhunter account'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), _other);
      final send = find.widgetWithText(FilledButton, 'Send invitation');
      await tester.tap(send);
      await tester.tap(send);
      await tester.pump();
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      final request = h.transport.requests
          .where((r) => r.uri.path == _send)
          .single;
      expect(request.method, ApiMethod.post);
      expect(jsonDecode(request.body!), {'recipientUserId': _other});
      expect(request.headers['Authorization'], 'Bearer synthetic-first');
      pending.complete(_json(_invitation(outgoing: true), 201));
      await tester.pumpAndSettle();
      expect(find.text('Last confirmed: Pending'), findsOneWidget);
      await _tap(tester, _other);
      expect(find.text('Accept invitation'), findsNothing);
      await _tap(tester, 'Cancel invitation');
      expect(find.text('Cancelled'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Last confirmed: Cancelled'), findsOneWidget);
    },
  );

  for (final (action, status, label) in [
    ('accept', 1, 'Accepted'),
    ('reject', 2, 'Rejected'),
  ]) {
    testWidgets('recipient can $action, independent of GPS consent', (
      tester,
    ) async {
      final h = _Harness();
      var done = false;
      h.mock((request) {
        if (request.uri.path == '$_base/pending') {
          return _json(done ? [] : [_invitation()]);
        }
        expect(request.uri.path, '$_base/$_invite/$action');
        expect(request.method, ApiMethod.post);
        expect(request.body, isNull);
        done = true;
        return _json(_decision(status));
      });
      await h.open(tester);
      await _profile(tester);
      await _tap(tester, 'Friends');
      await _tap(tester, 'Trip invitation');
      expect(find.text('Invitation details'), findsOneWidget);
      expect(find.text('Cancel invitation'), findsNothing);
      await _tap(
        tester,
        action == 'accept' ? 'Accept invitation' : 'Reject invitation',
      );
      expect(find.text(label), findsOneWidget);
      if (action == 'accept') {
        expect(find.text('Trip membership confirmed'), findsOneWidget);
        expect(
          find.text('GPS sharing requires separate consent.'),
          findsOneWidget,
        );
      }
      expect(
        h.transport.requests.where((r) => r.uri.path.contains('gps')),
        isEmpty,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('No pending trip invitations'), findsOneWidget);
    });
  }

  test(
    'adapter rejects malformed data and invalid IDs and maps denied actions',
    () async {
      final h = _Harness();
      await h.session.authenticate(_Harness.credential);
      final api = h.api;
      final item = TripInvitation.fromJson(_invitation());
      final error = isA<ApiException>();
      await expectLater(
        api.send(const TripPlanRef('invalid'), const UserRef(_other)),
        throwsA(error.having((e) => e.kind, 'kind', ApiError.rejected)),
      );
      await expectLater(
        api.decide(item, InvitationAction.cancel),
        throwsA(error.having((e) => e.kind, 'kind', ApiError.forbidden)),
      );
      expect(h.transport.requests, isEmpty);
      for (final (code, kind) in [
        (401, ApiError.unauthorized),
        (403, ApiError.forbidden),
      ]) {
        h.mock((_) => TransportResponse(code, const []));
        await expectLater(
          api.decide(item, InvitationAction.accept),
          throwsA(error.having((e) => e.kind, 'kind', kind)),
        );
      }
      h.mock((_) => _json({..._decision(1), 'memberId': null}));
      await expectLater(
        api.decide(item, InvitationAction.accept),
        throwsA(error.having((e) => e.kind, 'kind', ApiError.invalidResponse)),
      );
      h.mock((_) => _json([_invitation(outgoing: true)]));
      await expectLater(
        api.pending(),
        throwsA(error.having((e) => e.kind, 'kind', ApiError.invalidResponse)),
      );
      h.session.dispose();
    },
  );

  test(
    'member removal uses owner-only DELETE contract and bool receipt',
    () async {
      final h = _Harness();
      await h.session.authenticate(_Harness.credential);
      h.mock((request) {
        expect(request.method, ApiMethod.delete);
        expect(request.uri.path, '/api/mobile/trips/$_plan/members/$_other');
        expect(request.body, isNull);
        return _json({'removed': true});
      });
      expect(
        await h.api.removeMember(
          const TripPlanRef(_plan),
          const UserRef(_other),
        ),
        isTrue,
      );
      h.session.dispose();
    },
  );

  testWidgets('logout and switching accounts discard pending invitations', (
    tester,
  ) async {
    final h = _Harness();
    final pending = Completer<TransportResponse>();
    h.mock(
      (request) => request.headers['Authorization'] == 'Bearer synthetic-first'
          ? pending.future
          : _json([]),
    );
    await h.open(tester);
    await _profile(tester);
    await tester.ensureVisible(find.text('Friends'));
    await tester.tap(find.text('Friends'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(WayhunterLoadingView), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tap(tester, 'Sign out');
    pending.complete(_json([_invitation()]));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'other@example.invalid');
    await tester.enterText(fields.last, 'SyntheticPassword42');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();
    await _profile(tester);
    await _tap(tester, 'Friends');
    expect(find.text('No pending trip invitations'), findsOneWidget);
    expect(find.text('Trip invitation'), findsNothing);
  });
}
