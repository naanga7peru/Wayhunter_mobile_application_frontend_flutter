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
import 'package:wayhunter_mobile/features/notifications/data/notifications_api.dart';
import 'package:wayhunter_mobile/features/notifications/domain/notification_models.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

const _base = '/api/mobile/notifications';
const _owner = '30000000-0000-0000-0000-000000000001';
const _other = '30000000-0000-0000-0000-000000000002';
const _event = '30000000-0000-0000-0000-000000000003';
const _plan = '30000000-0000-0000-0000-000000000004';
const _trip = '/api/mobile/trip-plans/$_plan';

TransportResponse _json(Object body) =>
    TransportResponse(200, utf8.encode(jsonEncode(body)));

Map<String, Object?> _item({
  int category = 1,
  int template = 1,
  int version = 1,
  bool read = false,
}) => {
  'eventId': _event,
  'category': category,
  'template': template,
  'templateVersion': version,
  'createdAtUtc': '2026-11-23T00:00:00+00:00',
  'readAtUtc': read ? '2026-11-23T01:00:00+00:00' : null,
  'target': {'category': category, 'id': _plan},
};

TransportResponse _page(List<Object> items, int unread) =>
    _json({'items': items, 'unreadCount': unread});

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
  NotificationsApi get api => NotificationsApi(client, session);

  void mock(FutureOr<TransportResponse> Function(TransportRequest) handle) {
    transport.respond = (request) {
      final other =
          request.headers['Authorization'] == 'Bearer synthetic-second';
      return switch (request.uri.path) {
        '/api/mobile/identity/me' => _json({
          'userId': other ? _other : _owner,
          'displayName': other ? 'Second visitor' : 'First visitor',
          'email': 'fixture@example.invalid',
        }),
        '/api/mobile/advertisements/active' => _json([]),
        '/api/mobile/auth/logout' => const TransportResponse(204, []),
        '/api/mobile/identity/login' => _json({
          'userId': _other,
          'accessToken': 'synthetic-second',
          'expiresAtUtc': '2099-01-01T00:00:00Z',
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
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'adapter maps exact methods, bearer, query, read body and preferences',
    () async {
      final h = _Harness();
      await h.session.authenticate(_Harness.credential);
      h.mock(
        (request) => switch ((request.method, request.uri.path)) {
          (ApiMethod.get, _base) => _page([_item()], 9),
          (ApiMethod.get, '$_base/preferences') => _json([
            {'category': 1, 'pushEnabled': true},
            {'category': 7, 'pushEnabled': false},
          ]),
          (ApiMethod.put, _) => const TransportResponse(204, []),
          _ => fail('Unexpected call'),
        },
      );
      final api = h.api;
      final page = await api.inbox();
      expect(page.unreadCount, 9);
      expect(page.items.single.eventId, _event);
      expect(page.items.single.tripPlanId, _plan);
      expect(page.items.single.isRead, isFalse);
      await api.markRead(_event);
      final prefs = await api.preferences();
      expect(prefs.first.category, NotificationCategory.trip);
      expect(prefs.first.pushEnabled, isTrue);
      await api.updatePreference(NotificationCategory.voucher, true);
      final requests = h.transport.requests;
      expect(requests.map((r) => r.uri.path), [
        _base,
        '$_base/$_event/read',
        '$_base/preferences',
        '$_base/preferences',
      ]);
      expect(requests.first.uri.queryParameters, {'limit': '30'});
      expect(requests[1].method, ApiMethod.put);
      expect(requests[1].body, isNull);
      expect(jsonDecode(requests.last.body!), {
        'category': 7,
        'pushEnabled': true,
      });
      for (final request in requests) {
        expect(request.headers['Authorization'], 'Bearer synthetic-first');
      }
      await expectLater(api.markRead('../bad'), throwsA(isA<ApiException>()));
      expect(h.transport.requests, hasLength(4));
      h.session.dispose();
    },
  );

  testWidgets('Home inbox shows loading, unavailable, retry and empty', (
    tester,
  ) async {
    final h = _Harness();
    final pending = Completer<TransportResponse>();
    h.mock((_) => pending.future);
    await h.open(tester);
    await tester.ensureVisible(find.text('Notifications'));
    await tester.tap(find.text('Notifications'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(WayhunterLoadingView), findsOneWidget);
    pending.complete(const TransportResponse(503, []));
    await tester.pumpAndSettle();
    expect(
      find.text('The notification service is unavailable.'),
      findsOneWidget,
    );
    h.mock((_) => _page([], 0));
    await _tap(tester, 'Retry');
    expect(find.text('0 unread'), findsOneWidget);
    expect(find.text('No notifications'), findsOneWidget);
  });

  testWidgets(
    'Mark as read keeps server state on failure and reloads after success',
    (tester) async {
      final h = _Harness();
      var rejected = true;
      var serverRead = false;
      var writes = 0;
      h.mock((request) {
        if (request.method == ApiMethod.get) {
          return _page([_item(read: serverRead)], serverRead ? 0 : 1);
        }
        writes++;
        if (rejected) return const TransportResponse(409, []);
        serverRead = true;
        return const TransportResponse(204, []);
      });
      await h.open(tester);
      await _tap(tester, 'Notifications');
      expect(find.text('1 unread'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      await _tap(tester, 'Mark as read');
      expect(find.text('1 unread'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Mark as read'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Mark as read'))
            .onPressed,
        isNull,
      );
      rejected = false;
      await _tap(tester, 'Retry');
      expect(writes, 1);
      await _tap(tester, 'Mark as read');
      expect(find.text('0 unread'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Mark as read'), findsNothing);
      expect(writes, 2);
    },
  );

  testWidgets(
    'Profile links to inbox preferences and retains Wallet shortcut',
    (tester) async {
      final h = _Harness();
      var enabled = false;
      h.mock((request) {
        if (request.uri.path == _base) return _page([], 0);
        if (request.method == ApiMethod.put) {
          expect(jsonDecode(request.body!), {
            'category': 1,
            'pushEnabled': true,
          });
          enabled = true;
          return const TransportResponse(204, []);
        }
        return _json([
          {'category': 1, 'pushEnabled': enabled},
          {'category': 2, 'pushEnabled': false},
        ]);
      });
      await h.open(tester);
      await _tap(tester, 'Profile');
      await _tap(tester, 'Wallet');
      expect(find.text('Wallet balance unavailable'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'Notifications');
      await _tap(tester, 'Notification preferences');
      final trip = find.widgetWithText(SwitchListTile, 'Trip');
      expect(tester.widget<SwitchListTile>(trip).value, isFalse);
      await _tap(tester, 'Trip');
      expect(tester.widget<SwitchListTile>(trip).value, isTrue);
      expect(find.text('Safety'), findsOneWidget);
    },
  );

  testWidgets(
    'safe trip reminder opens read-only detail and expired or denied targets stay in inbox',
    (tester) async {
      final h = _Harness();
      var forbidden = false;
      var expired = false;
      h.mock((request) {
        if (request.uri.path == _base) return _page([_item()], 1);
        expect(request.uri.path, _trip);
        expect(request.method, ApiMethod.get);
        if (forbidden) return const TransportResponse(403, []);
        return _json({
          'tripPlanId': _plan,
          'tripName': 'Synthetic reminder trip',
          'startDate': expired ? '2000-01-01' : '2099-01-01',
          'endDate': expired ? '2000-01-02' : '2099-01-02',
          'budgetLkr': 3000,
          'vehicleType': 'Van',
          'headcount': 2,
          'stops': [],
          'rowVersion': 'AAAAAAAAAAE=',
        });
      });
      await h.open(tester);
      await _tap(tester, 'Notifications');
      await _tap(tester, 'View details');
      expect(find.text('Synthetic reminder trip'), findsOneWidget);
      expect(find.text('Start trip'), findsNothing);
      await _tap(tester, 'Close');
      expired = true;
      await _tap(tester, 'View details');
      expect(
        find.text('This notification destination is unavailable.'),
        findsOneWidget,
      );
      await _tap(tester, 'Close');
      forbidden = true;
      await _tap(tester, 'View details');
      expect(
        find.text('This notification destination is unavailable.'),
        findsOneWidget,
      );
      await _tap(tester, 'Close');
      expect(find.text('1 unread'), findsOneWidget);
    },
  );

  testWidgets(
    'unknown notification version opens safe fallback without requesting a target',
    (tester) async {
      final h = _Harness();
      h.mock((request) {
        expect(request.uri.path, _base);
        return _page([_item(version: 99)], 1);
      });
      await h.open(tester);
      await _tap(tester, 'Notifications');
      expect(find.text('Notification'), findsOneWidget);
      await _tap(tester, 'View details');
      expect(
        find.text('This notification destination is unavailable.'),
        findsOneWidget,
      );
      await _tap(tester, 'Close');
      expect(find.text('1 unread'), findsOneWidget);
    },
  );

  testWidgets(
    'logout and a new login discard a pending previous-account inbox',
    (tester) async {
      final h = _Harness();
      final stale = Completer<TransportResponse>();
      h.mock(
        (request) =>
            request.headers['Authorization'] == 'Bearer synthetic-first'
            ? stale.future
            : _page([], 0),
      );
      await h.open(tester);
      await tester.ensureVisible(find.text('Notifications'));
      await tester.tap(find.text('Notifications'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(WayhunterLoadingView), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'Profile');
      await _tap(tester, 'Sign out');
      stale.complete(_page([_item()], 9));
      await tester.pumpAndSettle();
      expect(find.text('Trip reminder'), findsNothing);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'other@example.invalid');
      await tester.enterText(fields.last, 'SyntheticPassword42');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();
      await _tap(tester, 'Notifications');
      expect(find.text('0 unread'), findsOneWidget);
      expect(find.text('Trip reminder'), findsNothing);
    },
  );

  test('adapter rejects account changes and malformed event IDs', () async {
    final h = _Harness();
    await h.session.authenticate(_Harness.credential);
    final api = h.api;
    h.mock(
      (_) => _page([
        {..._item(), 'eventId': 'malformed'},
      ], 1),
    );
    await expectLater(
      api.inbox(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.kind,
          'kind',
          ApiError.invalidResponse,
        ),
      ),
    );
    final pending = Completer<TransportResponse>();
    h.mock((_) => pending.future);
    final checked = expectLater(
      api.inbox(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.kind,
          'kind',
          ApiError.unauthorized,
        ),
      ),
    );
    await h.session.clear();
    pending.complete(_page([_item()], 1));
    await checked;
    h.session.dispose();
  });
}
