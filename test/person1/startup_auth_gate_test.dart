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
import 'package:wayhunter_mobile/features/auth/presentation/views/sign_in_screen.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

const _first = '2d9a7616-35c2-4ebf-a840-d7c69f5ad114';
const _second = 'dcae920f-4b98-43ab-9778-6aab01ae602f';
const _savedToken = 'synthetic-saved-token';

TransportResponse _json(int status, Object body) =>
    TransportResponse(status, utf8.encode(jsonEncode(body)));

class _Transport implements HttpTransport {
  final requests = <TransportRequest>[];
  String? _validatedBearer;
  FutureOr<TransportResponse> Function(TransportRequest) respond = (_) =>
      throw StateError('Unexpected network request');

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    final path = request.uri.path;
    final bearer = request.headers['Authorization'];
    if (path == '/api/mobile/advertisements/active') return _json(200, []);
    // Dashboard reads follow startup verification and are outside the gate assertions.
    if (path == '/api/mobile/identity/me' &&
        bearer != null &&
        bearer == _validatedBearer) {
      return _json(200, {
        'userId': bearer == 'Bearer synthetic-second' ? _second : _first,
        'displayName': 'Synthetic visitor',
        'email': 'visitor@example.invalid',
      });
    }
    requests.add(request);
    final response = await respond(request);
    if (response.statusCode == 200 && path == '/api/mobile/identity/me') {
      _validatedBearer = bearer;
    } else if (response.statusCode == 200 &&
        path == '/api/mobile/identity/login') {
      final payload = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      _validatedBearer = 'Bearer ${payload['accessToken']}';
    }
    return response;
  }
}

class _Store implements CredentialStore {
  SessionCredential? value;
  Completer<SessionCredential?>? pendingRead;
  bool failRead = false;
  bool failClear = false;
  int reads = 0;

  @override
  Future<SessionCredential?> read() async {
    reads++;
    if (failRead) throw const CredentialStorageException();
    return pendingRead == null ? value : await pendingRead!.future;
  }

  @override
  Future<void> clear() async {
    if (failClear) throw const CredentialStorageException();
    value = null;
  }

  @override
  Future<void> write(SessionCredential credential) async => value = credential;
}

class _Harness {
  _Harness({bool saved = false}) {
    if (saved) {
      store.value = const SessionCredential(
        user: UserRef(_first),
        accessToken: _savedToken,
      );
    }
  }

  final store = _Store();
  final transport = _Transport();
  late final session = SessionController(store);
  late final api = ApiClient(
    baseUrl: Uri.https('example.invalid'),
    transport: transport,
    tokens: session,
  );

  Widget app({bool configured = true}) => FoundationServices(
    api: api,
    session: session,
    child: WayhunterApp.authenticated(apiConfigured: configured),
  );
}

Finder get _signIn => find.byType(SignInScreen);
Finder get _shell => find.byType(NavigationBar);

NavigatorState _navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator));

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester, String email) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.first, email);
  await tester.enterText(fields.last, 'SyntheticPass42');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fresh installation restores once and opens Sign In', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(_signIn, findsOneWidget);
    expect(_shell, findsNothing);
    expect(harness.store.reads, 1);
    expect(harness.transport.requests, isEmpty);
  });

  testWidgets('missing API origin shows configuration unavailable', (
    tester,
  ) async {
    final harness = _Harness(saved: true);
    await tester.pumpWidget(harness.app(configured: false));
    await tester.pumpAndSettle();
    expect(find.text('Authentication is unavailable'), findsOneWidget);
    expect(_shell, findsNothing);
    expect(harness.store.reads, 0);
  });

  testWidgets('saved session waits for /me then enables Person 2 navigation', (
    tester,
  ) async {
    final harness = _Harness(saved: true);
    final verification = Completer<TransportResponse>();
    harness.transport.respond = (_) => verification.future;
    await tester.pumpWidget(harness.app());
    await tester.pump();
    final request = harness.transport.requests.single;
    expect(request.method, ApiMethod.get);
    expect(request.uri.path, '/api/mobile/identity/me');
    expect(request.headers['Authorization'], 'Bearer $_savedToken');
    expect(_shell, findsNothing);

    verification.complete(_json(200, {'userId': _first}));
    await tester.pumpAndSettle();
    expect(_shell, findsOneWidget);
    await _tap(tester, 'Profile');
    await _tap(tester, 'Wallet');
    expect(find.text('Wallet balance unavailable'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tap(tester, 'My Hunts');
    expect(find.text('Hunt history unavailable'), findsOneWidget);
    expect(harness.store.reads, 1);
  });

  for (final (description, response) in [
    ('rejected', const TransportResponse(401, [])),
    ('forbidden', const TransportResponse(403, [])),
    ('mismatched', _json(200, {'userId': _second})),
  ]) {
    testWidgets('$description credential is cleared before Sign In', (
      tester,
    ) async {
      final harness = _Harness(saved: true);
      harness.transport.respond = (_) => response;
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(_signIn, findsOneWidget);
      expect(_shell, findsNothing);
      expect(harness.store.value, isNull);
      expect(harness.session.accessToken, isNull);
    });
  }

  testWidgets(
    'network failure keeps credentials and retries /me without rereading',
    (tester) async {
      final harness = _Harness(saved: true);
      harness.transport.respond = (_) => throw const TransportFailure();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.text('Could not verify your session'), findsOneWidget);
      expect(_shell, findsNothing);
      expect(harness.store.value?.accessToken, _savedToken);
      harness.transport.respond = (_) => _json(200, {'userId': _first});
      await _tap(tester, 'Retry');
      expect(_shell, findsOneWidget);
      expect(harness.store.reads, 1);
      expect(harness.transport.requests, hasLength(2));
    },
  );

  testWidgets('signed out named destinations never build protected screens', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    for (final name in [
      AppRoutes.home,
      AppRoutes.hunter,
      AppRoutes.games,
      AppRoutes.traveller,
      AppRoutes.wallet,
      AppRoutes.leaderboard,
      AppRoutes.profile,
    ]) {
      unawaited(_navigator(tester).pushNamed<void>(name));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to access this page'), findsOneWidget);
      expect(_shell, findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_signIn, findsOneWidget);
    }
  });

  testWidgets('login and logout replace history and isolate the next account', (
    tester,
  ) async {
    final harness = _Harness();
    harness.transport.respond = (request) {
      if (request.uri.path == '/api/mobile/auth/logout') {
        expect(request.headers['Authorization'], 'Bearer synthetic-first');
        return const TransportResponse(503, []);
      }
      expect(request.uri.path, '/api/mobile/identity/login');
      final first =
          jsonDecode(request.body!)['email'] == 'first@example.invalid';
      return _json(200, {
        'userId': first ? _first : _second,
        'accessToken': first ? 'synthetic-first' : 'synthetic-second',
        'expiresAtUtc': '2099-01-01T00:00:00Z',
      });
    };
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        AppRoutes.wallet;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(_signIn, findsOneWidget);
    expect(_shell, findsNothing);
    await _login(tester, 'first@example.invalid');
    expect(_shell, findsOneWidget);
    expect(harness.session.state.user?.id, _first);

    await _tap(tester, 'Location Hunter');
    final protectedNavigator = _navigator(tester);
    unawaited(protectedNavigator.pushNamed<void>(AppRoutes.profile));
    await tester.pumpAndSettle();
    expect(protectedNavigator.canPop(), isTrue);
    await _tap(tester, 'Sign out');
    expect(protectedNavigator.mounted, isFalse);
    expect(_signIn, findsOneWidget);
    expect(harness.store.value, isNull);
    expect(
      find.textContaining('Server revocation could not be confirmed'),
      findsOneWidget,
    );
    expect(_navigator(tester).canPop(), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_shell, findsNothing);

    await _login(tester, 'second@example.invalid');
    expect(harness.session.state.user?.id, _second);
    expect(tester.widget<NavigationBar>(_shell).selectedIndex, 0);
    expect(find.text('Modules'), findsOneWidget);
    expect(_navigator(tester).canPop(), isFalse);
  });

  testWidgets('signing out during a pending secure read discards the restore', (
    tester,
  ) async {
    final harness = _Harness(saved: true);
    final restored = harness.store.value;
    final pending = harness.store.pendingRead = Completer<SessionCredential?>();
    await tester.pumpWidget(harness.app());
    await tester.pump();
    await tester.tap(find.text('Sign out'));
    await tester.pump();
    expect(_shell, findsNothing);
    pending.complete(restored);
    await tester.pumpAndSettle();
    expect(_signIn, findsOneWidget);
    expect(harness.store.value, isNull);
    expect(harness.transport.requests, isEmpty);
  });

  testWidgets('signing out during /me ignores its late success', (
    tester,
  ) async {
    final harness = _Harness(saved: true);
    final verification = Completer<TransportResponse>();
    harness.transport.respond = (request) => request.method == ApiMethod.get
        ? verification.future
        : const TransportResponse(204, []);
    await tester.pumpWidget(harness.app());
    await tester.pump();
    await _tap(tester, 'Sign out');
    verification.complete(_json(200, {'userId': _first}));
    await tester.pumpAndSettle();
    expect(_signIn, findsOneWidget);
    expect(_shell, findsNothing);
    expect(harness.store.value, isNull);
    expect(harness.transport.requests, hasLength(2));
  });

  testWidgets('secure read failure is explicit and recoverable', (
    tester,
  ) async {
    final harness = _Harness();
    harness.store.failRead = true;
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(find.text('Could not read secure session storage'), findsOneWidget);
    expect(_shell, findsNothing);
    harness.store.failRead = false;
    await _tap(tester, 'Retry');
    expect(_signIn, findsOneWidget);
    expect(harness.store.reads, 2);
  });

  testWidgets(
    'failed durable logout hides the shell and requires a clear retry',
    (tester) async {
      final harness = _Harness(saved: true);
      harness.transport.respond = (request) => request.method == ApiMethod.get
          ? _json(200, {'userId': _first})
          : const TransportResponse(204, []);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await _tap(tester, 'Profile');
      harness.store.failClear = true;
      await _tap(tester, 'Sign out');
      expect(
        find.text('Could not clear secure session storage'),
        findsOneWidget,
      );
      expect(_signIn, findsNothing);
      expect(_shell, findsNothing);
      expect(harness.session.accessToken, isNull);
      expect(harness.store.value, isNotNull);
      harness.store.failClear = false;
      await _tap(tester, 'Retry');
      expect(harness.store.value, isNull);
      expect(_signIn, findsOneWidget);
      expect(harness.transport.requests, hasLength(2));
    },
  );
}
