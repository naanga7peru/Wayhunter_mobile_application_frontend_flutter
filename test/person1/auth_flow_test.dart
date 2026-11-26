import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/router/app_router.dart';
import 'package:wayhunter_mobile/app/router/person1_routes.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/features/auth/data/identity_api.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_flow.dart';
import 'package:wayhunter_mobile/features/auth/presentation/views/sign_in_screen.dart';

const email = 'person1@example.invalid';
const password = 'SyntheticPassword42';
const token = 'synthetic-bearer';
const userId = '137f9d87-ed6b-4017-b82c-ade4192afabc';
const identity = '/api/mobile/identity';

TransportResponse jsonResponse(int status, Object body) =>
    TransportResponse(status, utf8.encode(jsonEncode(body)));

class _Transport implements HttpTransport {
  final requests = <TransportRequest>[];
  late FutureOr<TransportResponse> Function(TransportRequest) respond;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return respond(request);
  }
}

class _Store implements CredentialStore {
  SessionCredential? credential;

  @override
  Future<SessionCredential?> read() async => credential;
  @override
  Future<void> write(SessionCredential value) async => credential = value;
  @override
  Future<void> clear() async => credential = null;
}

void main() {
  late _Transport transport;
  late _Store storage;
  late SessionController session;

  setUp(() {
    transport = _Transport();
    storage = _Store();
  });

  tearDown(() => session.dispose());

  ApiClient client({bool configured = true}) => ApiClient(
    baseUrl: configured ? Uri.https('example.invalid') : null,
    transport: transport,
    tokens: session,
  );

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
  }

  Future<void> open(WidgetTester tester, {bool configured = true}) async {
    session = SessionController(storage);
    final router = AppRouter((_) {});
    await tester.pumpWidget(
      FoundationServices(
        api: client(configured: configured),
        session: session,
        child: MaterialApp(
          onGenerateRoute: router.onGenerateRoute,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(person1AuthRoute),
                child: const Text('Open auth'),
              ),
            ),
          ),
        ),
      ),
    );
    await tap(tester, find.text('Open auth'));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, List<String> values) async {
    final fields = find.byType(TextFormField);
    for (var index = 0; index < values.length; index++) {
      await tester.ensureVisible(fields.at(index));
      await tester.enterText(fields.at(index), values[index]);
    }
  }

  testWidgets('login validates and persists only a confirmed response once', (
    tester,
  ) async {
    final response = Completer<TransportResponse>();
    transport.respond = (_) => response.future;
    await open(tester);
    final submit = find.widgetWithText(FilledButton, 'Sign In');
    await tap(tester, submit);
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(transport.requests, isEmpty);

    await enter(tester, [' $email ', password]);
    await tap(tester, submit);
    await tester.tap(submit);
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(transport.requests, hasLength(1));
    expect(session.accessToken, isNull);
    final request = transport.requests.single;
    expect(request.uri.path, '$identity/login');
    expect(request.method, ApiMethod.post);
    expect(request.headers['Authorization'], isNull);
    expect(jsonDecode(request.body!), {'email': email, 'password': password});

    response.complete(
      jsonResponse(200, {
        'userId': userId,
        'accessToken': token,
        'expiresAtUtc': '2099-01-01T00:00:00Z',
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Signed in successfully.'), findsOneWidget);
    expect(session.state.user?.id, userId);
    expect(storage.credential?.accessToken, token);
  });

  testWidgets('login handles unauthorized and network retry safely', (
    tester,
  ) async {
    transport.respond = (_) =>
        jsonResponse(401, {'error': 'synthetic payload'});
    await open(tester);
    await enter(tester, [email, password]);
    final submit = find.widgetWithText(FilledButton, 'Sign In');
    await tap(tester, submit);
    await tester.pumpAndSettle();
    expect(
      find.text('Could not sign in with those credentials.'),
      findsOneWidget,
    );
    expect(find.text('synthetic payload'), findsNothing);
    transport.respond = (_) => throw const TransportFailure();
    await tap(tester, submit);
    await tester.pumpAndSettle();
    expect(find.text('Could not reach Wayhunter. Try again.'), findsOneWidget);
    expect(transport.requests, hasLength(2));
    expect(storage.credential, isNull);
  });

  testWidgets('missing backend configuration fails without a transport call', (
    tester,
  ) async {
    await open(tester, configured: false);
    await enter(tester, [email, password]);
    await tap(tester, find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();
    expect(
      find.text('Authentication is unavailable on this app configuration.'),
      findsOneWidget,
    );
    expect(transport.requests, isEmpty);
    expect(storage.credential, isNull);
  });

  testWidgets(
    'registration hands off to OTP and returns to Sign In after verification',
    (tester) async {
      transport.respond = (request) => switch (request.uri.path) {
        '$identity/register' => jsonResponse(201, {
          'userId': userId,
          'displayName': 'Demo User',
          'requiresOtpVerification': true,
        }),
        '$identity/resend-otp' => switch (transport.requests
            .where((entry) => entry.uri.path.endsWith('/resend-otp'))
            .length) {
          1 => const TransportResponse(429, [], retryAfter: '12'),
          2 => const TransportResponse(429, [], retryAfter: 'unknown'),
          _ => const TransportResponse(202, []),
        },
        '$identity/verify-otp' =>
          jsonDecode(request.body!)['code'] == '123456'
              ? const TransportResponse(204, [])
              : jsonResponse(400, {'error': 'invalid_or_expired_otp'}),
        _ => throw StateError('Unexpected route'),
      };
      await open(tester);
      await tap(tester, find.text('Create Account'));
      await tester.pumpAndSettle();
      final register = find.widgetWithText(FilledButton, 'Create Account');
      await tap(tester, register);
      await tester.pumpAndSettle();
      expect(transport.requests, isEmpty);
      await enter(tester, [' Demo User ', ' $email ', password, password]);
      await tap(tester, register);
      await tester.pumpAndSettle();
      expect(jsonDecode(transport.requests.single.body!), {
        'displayName': 'Demo User',
        'email': email,
        'password': password,
        'confirmPassword': password,
      });
      expect(find.textContaining(email), findsOneWidget);
      expect(find.text('Resend OTP'), findsNothing);
      final code = find.byType(TextField);
      final verify = find.widgetWithText(FilledButton, 'Verify OTP');
      await tester.enterText(code, '000000');
      await tap(tester, verify);
      await tester.pumpAndSettle();
      expect(find.textContaining('Incorrect or expired OTP'), findsOneWidget);

      final resend = find.text('Resend OTP');
      await tester.pump(const Duration(seconds: 60));
      await tap(tester, resend);
      await tester.pumpAndSettle();
      expect(find.textContaining('Too many requests'), findsOneWidget);
      expect(find.text('Resend code in 12 seconds'), findsOneWidget);
      expect(resend, findsNothing);
      await tester.pump(const Duration(seconds: 11));
      expect(find.text('Resend code in 1 second'), findsOneWidget);
      expect(resend, findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(
        transport.requests.where((r) => r.uri.path == '$identity/resend-otp'),
        hasLength(1),
      );
      await tap(tester, resend);
      await tester.pumpAndSettle();
      expect(find.text('Resend code in 60 seconds'), findsOneWidget);
      await tester.pump(const Duration(seconds: 60));
      await tap(tester, resend);
      await tester.pumpAndSettle();
      expect(find.text('A new OTP has been requested'), findsOneWidget);
      expect(find.text('Resend code in 60 seconds'), findsOneWidget);

      await tester.enterText(code, '123456');
      await tap(tester, verify);
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(jsonDecode(transport.requests.last.body!), {
        'email': email,
        'code': '123456',
      });
      expect(storage.credential, isNull);
    },
  );

  testWidgets(
    'password recovery uses a separate token and returns to Sign In',
    (tester) async {
      transport.respond = (request) => switch (request.uri.path) {
        '$identity/forgot-password' => jsonResponse(202, {
          'message': IdentityApi.recoveryConfirmation,
        }),
        '$identity/reset-password' => const TransportResponse(204, []),
        _ => throw StateError('Unexpected route'),
      };
      await open(tester);
      await tap(tester, find.text('Forgot Password'));
      await tester.pumpAndSettle();
      await enter(tester, [email]);
      await tap(tester, find.text('Send reset instructions'));
      await tester.pumpAndSettle();
      expect(find.text(IdentityApi.recoveryConfirmation), findsOneWidget);
      expect(jsonDecode(transport.requests.single.body!), {'email': email});
      await tap(tester, find.text('Enter recovery token'));
      await tester.pumpAndSettle();
      await enter(tester, ['synthetic-recovery-token', password, password]);
      await tap(tester, find.widgetWithText(FilledButton, 'Reset Password'));
      await tester.pumpAndSettle();
      expect(jsonDecode(transport.requests.last.body!), {
        'email': email,
        'token': 'synthetic-recovery-token',
        'newPassword': password,
        'confirmPassword': password,
      });
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(storage.credential, isNull);
    },
  );

  test('OTP verification rejects an unexpected success status', () async {
    session = SessionController(storage);
    transport.respond = (_) => const TransportResponse(200, []);
    await expectLater(
      IdentityApi(client()).verifyOtp(email, '123456'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiError.invalidResponse)
            .having((e) => e.statusCode, 'statusCode', 200),
      ),
    );
  });

  test(
    'OTP resend accepts HTTP 202 and rejects unrelated success statuses',
    () async {
      session = SessionController(storage);
      final api = IdentityApi(client());
      transport.respond = (_) => const TransportResponse(204, []);
      await expectLater(
        api.resendOtp(email),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiError.invalidResponse)
              .having((e) => e.statusCode, 'statusCode', 204),
        ),
      );
      transport.respond = (_) => const TransportResponse(202, []);
      await api.resendOtp(email);
      expect(
        transport.requests.map((r) => r.uri.path),
        List.filled(2, '$identity/resend-otp'),
      );
    },
  );

  test('missing login response fields fail closed', () async {
    session = SessionController(storage);
    transport.respond = (_) => jsonResponse(200, {'userId': userId});
    await expectLater(
      IdentityApi(client()).login(email, password),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiError.invalidResponse,
        ),
      ),
    );
    expect(storage.credential, isNull);
  });

  test(
    'owner lookup and logout use bearer and clear locally after remote failure',
    () async {
      transport.respond = (request) => switch (request.uri.path) {
        '$identity/login' => jsonResponse(200, {
          'userId': userId,
          'accessToken': token,
          'expiresAtUtc': '2099-01-01T00:00:00Z',
        }),
        '$identity/me' => jsonResponse(200, {'userId': userId}),
        '/api/mobile/auth/logout' => const TransportResponse(503, []),
        _ => throw StateError('Unexpected route'),
      };
      session = SessionController(storage);
      final api = IdentityApi(client());
      await session.authenticate((await api.login(email, password)).credential);
      expect((await api.currentUser()).id, userId);
      expect(await AuthFlow.logout(api, session), isFalse);
      expect(transport.requests[1].method, ApiMethod.get);
      expect(transport.requests.last.method, ApiMethod.post);
      expect(transport.requests.last.body, isNull);
      for (final request in transport.requests.skip(1)) {
        expect(request.headers['Authorization'], 'Bearer $token');
      }
      expect(storage.credential, isNull);
      expect(session.accessToken, isNull);
    },
  );
}
