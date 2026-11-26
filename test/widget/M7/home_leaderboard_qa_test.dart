import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/features/friends/presentation/friends_screen.dart';
import 'package:wayhunter_mobile/features/home/presentation/views/home_screen.dart';
import 'package:wayhunter_mobile/features/leaderboards/presentation/leaderboard_screens.dart';
import 'package:wayhunter_mobile/features/profile/presentation/my_profile_screen.dart';
import 'package:wayhunter_mobile/features/wallet/presentation/wallet_screens.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

import '../../person1/wallet_balance_fixture.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('authenticated leaderboard visibility at ${width.toInt()} px', (
      tester,
    ) async {
      await _openApp(tester, width: width);
      final home = find.byType(HomeScreen);
      final profile = find.byType(MyProfileScreen);
      final board = find.byType(LeaderboardHomeScreen);

      expect(find.text('Hello, QA traveller'), findsOneWidget);
      _expectNoShortcut(home);
      await _tap(tester, _tab('Leaderboard'));
      expect(
        find.text('Choose a module to view its leaderboard.'),
        findsOneWidget,
      );
      expect(board, findsNothing);
      await _tap(tester, _tab('Home'));

      for (final (module, category) in [
        ('Traveler', 'Traveller'),
        ('Location Hunter', 'Hunter'),
        ('Game', 'Game'),
      ]) {
        await _tap(
          tester,
          find.descendant(of: home, matching: find.text(module)),
        );
        await _tap(tester, _tab('Leaderboard'));
        expect(board, findsOneWidget);
        final heading = find.text('$category rankings');
        expect(heading.hitTestable(), findsOneWidget);
        final header = find.ancestor(
          of: heading,
          matching: find.byType(WayhunterHeader),
        );
        expect(tester.getCenter(header).dx, width / 2);
        expect(tester.getSize(header).width, width == 320 ? 288 : 560);
        expect(find.text('Rankings unavailable'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _tap(tester, _tab('Home'));
      }

      await _tap(tester, _tab('Profile'));
      _expectNoShortcut(profile);
      await _tap(tester, find.text('Friends'));
      _expectNoShortcut(find.byType(FriendsScreen));
      expect(find.text('No pending trip invitations'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Wallet'));
      _expectNoShortcut(find.byType(WalletHomeScreen));
      expect(find.text('$fixtureSpendableCoins'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Home retries an existing profile read after access is denied', (
    tester,
  ) async {
    final transport = _Transport(denyFirstHomeProfileRead: true);
    await _openApp(tester, width: 320, transport: transport);
    expect(find.text('Could not load profile'), findsOneWidget);
    expect(
      find.text('Your account cannot access this information.'),
      findsOneWidget,
    );
    expect(find.text('Hello, QA traveller'), findsNothing);
    expect(find.text('Choose a module'), findsOneWidget);

    await _tap(tester, find.text('Retry'));
    expect(find.text('Hello, QA traveller'), findsOneWidget);
    expect(find.text('Could not load profile'), findsNothing);
    expect(transport.profileReads, 3);
  });
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void _expectNoShortcut(Finder screen) {
  expect(screen, findsOneWidget);
  expect(
    find.descendant(
      of: screen,
      matching: find.textContaining(
        RegExp(r'leaderboard|rankings', caseSensitive: false),
      ),
    ),
    findsNothing,
  );
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

const _owner = '20000000-0000-0000-0000-000000000001';

Future<void> _openApp(
  WidgetTester tester, {
  required double width,
  _Transport? transport,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final session = SessionController(_Store());
  final api = ApiClient(
    baseUrl: Uri.https('example.invalid'),
    transport: transport ?? _Transport(),
    tokens: session,
  );
  await tester.pumpWidget(
    FoundationServices(
      api: api,
      session: session,
      child: const WayhunterApp.authenticated(apiConfigured: true),
    ),
  );
  await tester.pumpAndSettle();
}

class _Store implements CredentialStore {
  SessionCredential? value = const SessionCredential(
    user: UserRef(_owner),
    accessToken: 'synthetic-qa-token',
  );

  @override
  Future<SessionCredential?> read() async => value;

  @override
  Future<void> write(SessionCredential credential) async => value = credential;

  @override
  Future<void> clear() async => value = null;
}

class _Transport implements HttpTransport {
  _Transport({this.denyFirstHomeProfileRead = false});

  final bool denyFirstHomeProfileRead;
  int profileReads = 0;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    switch (request.uri.path) {
      case '/api/mobile/identity/me':
        profileReads++;
        if (denyFirstHomeProfileRead && profileReads == 2) {
          return const TransportResponse(403, []);
        }
        return TransportResponse(
          200,
          utf8.encode(
            jsonEncode({
              'userId': _owner,
              'displayName': 'QA traveller',
              'email': 'qa@example.invalid',
            }),
          ),
        );
      case '/api/mobile/advertisements/active':
      case '/api/mobile/trip-invitations/pending':
      case '/api/mobile/hunter/places':
        return TransportResponse(200, utf8.encode('[]'));
      case walletBalancePath:
        return walletBalanceResponse();
      default:
        throw StateError('Unexpected QA request: ${request.uri.path}');
    }
  }
}
