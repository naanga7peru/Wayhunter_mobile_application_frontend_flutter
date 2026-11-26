import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/router/app_router.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/hunter/domain/hunter_history.dart';
import 'package:wayhunter_mobile/features/hunter/presentation/hunter_screens.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

import '../../foundation/api_client_test.dart' show FakeTransport;
import '../../foundation/session_and_device_test.dart'
    show MemoryCredentialStore;

void main() {
  testWidgets('Hunter validates the draft and returns from local review', (
    tester,
  ) async {
    await tester.pumpWidget(const WayhunterApp());
    await tester.tap(find.text('Location Hunter'));
    await tester.pumpAndSettle();
    expect(find.text('Published discoveries unavailable'), findsOneWidget);

    await tester.tap(find.text('Add New Place'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, '   ');
    await tester.ensureVisible(find.text('Review place details'));
    await tester.tap(find.text('Review place details'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a place name.'), findsOneWidget);
    expect(find.text('Enter a description.'), findsOneWidget);

    await tester.enterText(fields.first, '  Hill lookout  ');
    await tester.enterText(fields.last, 'A view over the valley.');
    await tester.ensureVisible(find.text('Review place details'));
    await tester.tap(find.text('Review place details'));
    await tester.pumpAndSettle();
    expect(find.text('Hill lookout'), findsOneWidget);
    expect(find.text('A view over the valley.'), findsOneWidget);
    expect(find.text('Guided 360° video: Unavailable'), findsOneWidget);
    final submit = find.widgetWithText(WayhunterButton, 'Submit for review');
    expect(tester.widget<WayhunterButton>(submit).onPressed, isNull);
    expect(find.text('Pending'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('  Hill lookout  '), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Add New Place'), findsOneWidget);
  });

  testWidgets('Hunter history keeps development examples separate', (
    tester,
  ) async {
    await tester.pumpWidget(const WayhunterApp());
    await tester.tap(find.text('Location Hunter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Hunts'));
    await tester.pumpAndSettle();
    expect(find.text('Hunt history unavailable'), findsOneWidget);
    expect(find.text('Approved'), findsNothing);

    await tester.tap(find.text('View development demo'));
    await tester.pumpAndSettle();
    expect(find.text('Development demo data'), findsOneWidget);
    for (final status in ['Pending', 'Approved', 'Rejected']) {
      expect(find.text(status), findsOneWidget);
    }
    await tester.tap(find.text('Sample lakeside path'));
    await tester.pumpAndSettle();
    expect(find.text('Development demo data'), findsOneWidget);
    expect(find.textContaining('Sample reason:'), findsOneWidget);
    expect(find.textContaining('Coins'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return to My Hunts'));
    await tester.pumpAndSettle();
    expect(find.text('Hunt history unavailable'), findsOneWidget);
    expect(find.text('Development demo data'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Add New Place'), findsOneWidget);
  });

  testWidgets('My Hunts loads, handles a read error, and retries to empty', (
    tester,
  ) async {
    final history = _RetryHistory();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MyHuntsScreen(history: history)),
      ),
    );
    expect(find.byType(WayhunterLoadingView), findsOneWidget);

    history.firstRead.completeError(StateError('Private diagnostic'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load hunts'), findsOneWidget);
    expect(find.text('Private diagnostic'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No hunts yet'), findsOneWidget);
  });

  testWidgets('Hunter Add New Place rejects unexpected route arguments', (
    tester,
  ) async {
    await tester.pumpWidget(const WayhunterApp());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed<void>(hunterAddNewPlaceRoute, arguments: 'unexpected');
    await tester.pumpAndSettle();
    expect(find.text('This destination is unavailable.'), findsOneWidget);
  });

  testWidgets(
    'authenticated Hunter routes retry discovery and refresh owner status',
    (tester) async {
      const id = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      const stamp = '2026-11-26T08:00:00Z';
      const summary = {
        'placeName': 'Owned lookout',
        'district': 'Kandy',
        'createdAtUtc': stamp,
        'submittedAtUtc': stamp,
      };
      final session = SessionController(MemoryCredentialStore());
      addTearDown(session.dispose);
      await session.authenticate(
        const SessionCredential(
          user: UserRef('owner-one'),
          accessToken: 'hunter-route-session',
        ),
      );
      var placesCalls = 0;
      final transport = FakeTransport((request) async {
        expect(request.method, ApiMethod.get);
        expect(request.headers['Authorization'], 'Bearer hunter-route-session');
        final Object data;
        switch (request.uri.path) {
          case '/api/mobile/hunter/places':
            if (placesCalls++ == 0) return const TransportResponse(503, []);
            data = [
              {
                'submissionId': id,
                'placeName': 'Published trail',
                'district': 'Kandy',
                'latitude': 7,
                'longitude': 80,
                'approvedAtUtc': stamp,
              },
            ];
          case '/api/mobile/hunter/submissions':
            data = [
              {...summary, 'submissionId': id, 'status': 1},
            ];
          case '/api/mobile/hunter/submissions/$id':
            data = {...summary, 'status': 3};
          default:
            fail('Unexpected Hunter endpoint');
        }
        return TransportResponse(200, utf8.encode(jsonEncode(data)));
      });
      final router = AppRouter((_) {});
      await tester.pumpWidget(
        FoundationServices(
          session: session,
          api: ApiClient(
            baseUrl: Uri.https('example.invalid'),
            transport: transport,
            tokens: session,
          ),
          child: MaterialApp(
            onGenerateRoute: router.onGenerateRoute,
            home: Scaffold(
              body: Builder(
                builder: (context) =>
                    router.destination(context, AppRoutes.hunter),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(String label) async {
        final target = find.text(label);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      expect(find.text('Could not load published discoveries'), findsOneWidget);
      await tap('Retry');
      expect(find.text('Published trail'), findsOneWidget);
      await tap('My Hunts');
      expect(find.text('Pending'), findsOneWidget);
      await tap('Owned lookout');
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Pending'), findsNothing);
      await session.clear();
      await tester.pumpAndSettle();
      expect(find.text('Hunt status unavailable'), findsOneWidget);
      expect(find.text('Owned lookout'), findsNothing);
    },
  );
}

class _RetryHistory implements HunterHistory {
  final firstRead = Completer<List<HuntSummary>>();
  bool _hasLoaded = false;

  @override
  Future<List<HuntSummary>> load() {
    if (_hasLoaded) return Future.value(const []);
    _hasLoaded = true;
    return firstRead.future;
  }
}
