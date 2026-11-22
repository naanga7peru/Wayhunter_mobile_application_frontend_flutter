import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

void main() {
  test('navigation IDs accept opaque IDs and reject unsafe strings', () {
    expect(isNavigationId('provider:place_42-v1.0'), isTrue);
    expect(isNavigationId('8f213ede-514e-468a-84b5-49833a302aa2'), isTrue);
    for (final value in [
      '',
      'a/b',
      '../place',
      ' x',
      'a\n',
      'a?key=2',
      'x' * 256,
    ]) {
      expect(isNavigationId(value), isFalse, reason: value);
    }
  });

  test('shared destinations carry typed arguments and stable names', () {
    const trip = ActiveTripArgs(
      plan: TripPlanRef('plan-12'),
      session: TripSessionRef('session-23'),
    );
    const destination = AppDestination.activeTrip(trip);
    expect(destination.name, 'traveller.activeTrip');
    expect(destination.arguments, same(trip));
    expect(AppRoutes.moduleHome(ModuleId.game), 'games.home');
  });

  testWidgets('module and leaderboard handle startup without a selection', (
    tester,
  ) async {
    await tester.pumpWidget(const WayhunterApp());
    await tester.tap(find.text('Modules'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a module'), findsOneWidget);

    await tester.tap(find.text('Leaderboard'));
    await tester.pumpAndSettle();
    expect(
      find.text('Choose a module to view its leaderboard.'),
      findsOneWidget,
    );
  });

  testWidgets('leaderboard follows all three Home module choices', (
    tester,
  ) async {
    await tester.pumpWidget(const WayhunterApp());
    for (final name in ['Traveler', 'Location Hunter', 'Game']) {
      await tester.tap(find.text(name).first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );

      await tester.tap(find.text('Leaderboard'));
      await tester.pumpAndSettle();
      expect(find.text('$name leaderboard'), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Profile opens Person 2 previews and Back returns to Profile', (
    tester,
  ) async {
    await tester.pumpWidget(const WayhunterApp());
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    for (final name in ['Wallet', 'My Hunts', 'My Games']) {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(find.text(name), findsOneWidget);
      expect(find.textContaining('Starter placeholder'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Development preview'), findsOneWidget);
    }
  });

  testWidgets('Hunter hands a typed PlaceRef to Traveller and Back returns', (
    tester,
  ) async {
    await tester.pumpWidget(
      const WayhunterApp(environmentLabel: 'development'),
    );
    await tester.tap(find.text('Location Hunter'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('SAMPLE: Preview adding a Hunter place to Traveler'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add place to trip'), findsOneWidget);
    expect(
      find.text('SAMPLE PREVIEW: Hunter place (backend approval unverified)'),
      findsOneWidget,
    );
    expect(find.text('Source: Hunter-approved place'), findsNothing);
    expect(find.textContaining('Starter placeholder'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.text('SAMPLE: Preview adding a Hunter place to Traveler'),
      findsOneWidget,
    );
  });

  testWidgets(
    'unknown routes, wrong types, and invalid IDs show a safe fallback',
    (tester) async {
      await tester.pumpWidget(const WayhunterApp());
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final invalid = <(String, Object?)>[
        ('unknown.route', null),
        (AppRoutes.addPlace, 'place-1'),
        (
          AppRoutes.addPlace,
          const PlaceRef('a/b', source: PlaceSource.externalProvider),
        ),
        (AppRoutes.leaderboard, null),
        (AppRoutes.userProfile, const UserRef('')),
        (AppRoutes.tripPlan, const TripPlanRef('../plan')),
        (
          AppRoutes.activeTrip,
          const ActiveTripArgs(
            plan: TripPlanRef('ok'),
            session: TripSessionRef(' '),
          ),
        ),
        (AppRoutes.wallet, const UserRef('unexpected')),
      ];
      for (final (name, arguments) in invalid) {
        navigator.pushNamed<void>(name, arguments: arguments);
        await tester.pumpAndSettle();
        expect(find.text('This destination is unavailable.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    },
  );
}
