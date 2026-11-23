import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/services/device_interfaces.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/features/settings/presentation/settings_screen.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

import 'wallet_balance_fixture.dart';

const _owner = '50000000-0000-0000-0000-000000000001';
const _other = '50000000-0000-0000-0000-000000000002';
const _preferences = '/api/mobile/notifications/preferences';

TransportResponse _json(Object value) =>
    TransportResponse(200, utf8.encode(jsonEncode(value)));

class _Store implements CredentialStore {
  SessionCredential? value = const SessionCredential(
    user: UserRef(_owner),
    accessToken: 'synthetic-first',
  );
  @override
  Future<SessionCredential?> read() async => value;
  @override
  Future<void> write(SessionCredential credential) async => value = credential;
  @override
  Future<void> clear() async => value = null;
}

class _PermissionProbe implements DevicePermissions {
  final checks = <DevicePermission>[];
  final requests = <DevicePermission>[];

  @override
  Future<DevicePermissionStatus> check(DevicePermission permission) async {
    checks.add(permission);
    return switch (permission) {
      DevicePermission.location => DevicePermissionStatus.denied,
      DevicePermission.camera => DevicePermissionStatus.granted,
      DevicePermission.microphone => DevicePermissionStatus.unavailable,
    };
  }

  @override
  Future<DevicePermissionStatus> request(DevicePermission permission) async {
    requests.add(permission);
    return DevicePermissionStatus.unavailable;
  }
}

class _Transport implements HttpTransport {
  final requests = <TransportRequest>[];
  bool failRemoteLogout = false;
  bool firstEnabled = true;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final second =
        request.headers['Authorization'] == 'Bearer synthetic-second';
    return switch (request.uri.path) {
      '/api/mobile/identity/me' => _json({
        'userId': second ? _other : _owner,
        'displayName': second ? 'Second visitor' : 'First visitor',
        'email': 'visitor@example.invalid',
      }),
      '/api/mobile/advertisements/active' => _json([]),
      walletBalancePath => walletBalanceResponse(),
      '/api/mobile/auth/logout' => TransportResponse(
        failRemoteLogout ? 503 : 204,
        const [],
      ),
      '/api/mobile/identity/login' => _json({
        'userId': _other,
        'accessToken': 'synthetic-second',
        'expiresAtUtc': '2099-01-01T00:00:00Z',
      }),
      _preferences => _preference(request, second),
      _ => fail('Unexpected request'),
    };
  }

  TransportResponse _preference(TransportRequest request, bool second) {
    if (request.method == ApiMethod.put) {
      expect(second, isFalse);
      final value = jsonDecode(request.body!) as Map<String, dynamic>;
      expect(value['category'], 1);
      firstEnabled = value['pushEnabled'] as bool;
      return const TransportResponse(204, []);
    }
    return _json([
      {'category': 1, 'pushEnabled': !second && firstEnabled},
    ]);
  }
}

class _Harness {
  final store = _Store();
  final transport = _Transport();
  final permissions = _PermissionProbe();
  late final session = SessionController(store);
  late final client = ApiClient(
    baseUrl: Uri.https('example.invalid'),
    transport: transport,
    tokens: session,
  );

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      FoundationServices(
        api: client,
        session: session,
        permissions: permissions,
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

Future<void> _settings(WidgetTester tester) async {
  await _tap(tester, 'Profile');
  await _tap(tester, 'Settings');
}

void main() {
  testWidgets('Profile opens Settings and preserves the Wallet shortcut', (
    tester,
  ) async {
    final h = _Harness();
    await h.open(tester);
    await _tap(tester, 'Profile');
    await _tap(tester, 'Wallet');
    expect(find.text('$fixtureSpendableCoins'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tap(tester, 'Settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    for (final entry in [
      'Account & Security',
      'Language',
      'Privacy & Permissions',
      'Notification preferences',
      'Help & About',
      'Sign out',
    ]) {
      expect(find.text(entry), findsOneWidget);
    }
    expect(h.permissions.checks, isEmpty);
    expect(h.permissions.requests, isEmpty);
    await _tap(tester, 'Help & About');
    expect(find.text('Wayhunter'), findsOneWidget);
  });

  testWidgets(
    'Account & Security explains recovery and disables unsupported changes',
    (tester) async {
      final h = _Harness();
      await h.open(tester);
      await _settings(tester);
      final before = h.transport.requests.length;
      await _tap(tester, 'Account & Security');
      expect(find.text('Password recovery'), findsOneWidget);
      expect(find.textContaining('Forgot Password on Sign In'), findsOneWidget);
      expect(find.text('Change password unavailable'), findsOneWidget);
      expect(find.text('Account deletion unavailable'), findsOneWidget);
      expect(h.transport.requests, hasLength(before));
    },
  );

  testWidgets(
    'Language settings show English and offer no unsupported language selection',
    (tester) async {
      final h = _Harness();
      await h.open(tester);
      await _settings(tester);
      await _tap(tester, 'Language');

      final english = find.text('App interface: English');
      expect(english, findsOneWidget);
      expect(find.text('Tamil and Sinhala unavailable'), findsOneWidget);
      expect(find.byType(DropdownButton<Locale>), findsNothing);
      expect(
        Localizations.localeOf(tester.element(english)).languageCode,
        'en',
      );
    },
  );

  testWidgets(
    'Privacy checks device state only on tap and sends no GPS consent',
    (tester) async {
      final h = _Harness();
      await h.open(tester);
      await _settings(tester);
      final before = h.transport.requests.length;
      await _tap(tester, 'Privacy & Permissions');
      expect(find.text('Trip GPS consent unavailable here'), findsOneWidget);
      expect(
        find.text('Account privacy and contact discovery unavailable'),
        findsOneWidget,
      );
      expect(h.permissions.checks, isEmpty);
      expect(h.permissions.requests, isEmpty);
      await _tap(tester, 'Check device permissions');
      expect(h.permissions.checks, DevicePermission.values);
      expect(find.text('Denied on this device'), findsOneWidget);
      expect(find.text('Allowed on this device'), findsOneWidget);
      expect(find.text('Device status unavailable'), findsOneWidget);
      expect(h.permissions.requests, isEmpty);
      expect(h.transport.requests, hasLength(before));
    },
  );

  testWidgets(
    'Settings opens the same server-backed notification preferences',
    (tester) async {
      final h = _Harness();
      await h.open(tester);
      await _settings(tester);
      await _tap(tester, 'Notification preferences');
      final trip = find.widgetWithText(SwitchListTile, 'Trip');
      expect(tester.widget<SwitchListTile>(trip).value, isTrue);
      await _tap(tester, 'Trip');
      expect(tester.widget<SwitchListTile>(trip).value, isFalse);
      final methods = h.transport.requests
          .where((request) => request.uri.path == _preferences)
          .map((r) => r.method);
      expect(methods, [ApiMethod.get, ApiMethod.put, ApiMethod.get]);
    },
  );

  testWidgets(
    'Settings sign out removes old routes and a new account has its own preferences',
    (tester) async {
      final h = _Harness();
      h.transport.failRemoteLogout = true;
      await h.open(tester);
      await _settings(tester);
      await _tap(tester, 'Notification preferences');
      expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Trip'))
            .value,
        isTrue,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'Sign out');
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(h.store.value, isNull);
      expect(h.session.accessToken, isNull);
      expect(h.transport.requests.last.uri.path, '/api/mobile/auth/logout');
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'second@example.invalid');
      await tester.enterText(fields.last, 'SyntheticPass42');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Hello, Second visitor'), findsOneWidget);
      await _settings(tester);
      await _tap(tester, 'Notification preferences');
      expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Trip'))
            .value,
        isFalse,
      );
      expect(
        h.transport.requests.last.headers['Authorization'],
        'Bearer synthetic-second',
      );
      expect(h.permissions.requests, isEmpty);
    },
  );
}
