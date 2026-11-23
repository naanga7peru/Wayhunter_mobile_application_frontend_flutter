import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/leaderboards/data/leaderboard_preview.dart';
import 'package:wayhunter_mobile/features/leaderboards/presentation/leaderboard_screens.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

void main() {
  const demoLabel = 'DEMO · Sample rankings';

  Future<void> openPreview(WidgetTester tester) async {
    await tester.tap(find.text('Open DEMO preview'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'unavailable rankings stay separate and preview requires opt-in',
    (tester) async {
      final requests = <ModuleId>[];
      await tester.pumpWidget(
        _screen((module) async {
          requests.add(module);
          return loadLeaderboardPreview(module);
        }),
      );

      expect(find.text('Traveller rankings'), findsOneWidget);
      expect(find.text('Rankings unavailable'), findsOneWidget);
      expect(find.text(demoLabel), findsNothing);
      await tester.tap(find.text('Hunter'));
      await tester.pumpAndSettle();
      expect(find.text('Hunter rankings'), findsOneWidget);
      expect(requests, isEmpty);

      await openPreview(tester);
      expect(requests, [ModuleId.hunter]);
      expect(find.text(demoLabel), findsOneWidget);
      expect(find.text('800 approved Hunter Coins'), findsOneWidget);

      await tester.tap(find.text('Game'));
      await tester.pumpAndSettle();
      expect(requests, [ModuleId.hunter, ModuleId.game]);
      expect(find.text('Game rankings'), findsOneWidget);
      expect(find.text('400 approved Game Coins'), findsOneWidget);
      expect(find.text('800 approved Hunter Coins'), findsNothing);
      expect(find.text(demoLabel), findsOneWidget);

      await tester.tap(find.text('Exit DEMO preview'));
      await tester.pumpAndSettle();
      expect(find.text('Rankings unavailable'), findsOneWidget);
      expect(find.text('Sample Current User'), findsNothing);
      expect(find.text(demoLabel), findsNothing);
    },
  );

  testWidgets(
    'preview highlights the sample current user and opens details above the shell',
    (tester) async {
      await tester.pumpWidget(const WayhunterApp());
      await tester.tap(find.text('Traveler').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leaderboard'));
      await tester.pumpAndSettle();
      await openPreview(tester);

      final currentUser = find.widgetWithText(ListTile, 'Sample Current User');
      expect(tester.widget<ListTile>(currentUser).selected, isTrue);
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Sample Explorer'))
            .selected,
        isFalse,
      );
      expect(find.text('9 valid finished trips'), findsOneWidget);
      expect(find.text('You (DEMO)'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(currentUser);
      await tester.pumpAndSettle();
      expect(find.text('Ranking detail'), findsOneWidget);
      expect(find.text('Sample Current User'), findsOneWidget);
      expect(find.text('Position #2'), findsOneWidget);
      expect(find.text('9 valid finished trips'), findsOneWidget);
      expect(find.text(demoLabel), findsOneWidget);
      expect(find.text(previewCurrentUser.id), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(currentUser, findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(find.text('Traveller rankings'), findsOneWidget);
    },
  );

  testWidgets('preview shows labeled loading and empty states', (tester) async {
    final response = Completer<List<LeaderboardEntry>>();
    await tester.pumpWidget(_screen((_) => response.future));
    await tester.tap(find.text('Open DEMO preview'));
    await tester.pump();
    expect(find.byType(WayhunterLoadingView), findsOneWidget);
    expect(find.text(demoLabel), findsOneWidget);

    response.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No DEMO rankings yet'), findsOneWidget);
    expect(find.text(demoLabel), findsOneWidget);
  });

  testWidgets(
    'preview retry reloads the same category and omits absent scores',
    (tester) async {
      final requests = <ModuleId>[];
      await tester.pumpWidget(
        _screen((module) async {
          requests.add(module);
          if (requests.length == 1) throw StateError('Fixture failure');
          return const [
            LeaderboardEntry(
              user: UserRef('sample-user'),
              displayName: 'Sample Player',
              position: 4,
            ),
          ];
        }),
      );
      await openPreview(tester);
      expect(find.text('Could not load DEMO rankings'), findsOneWidget);
      expect(find.text(demoLabel), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(requests, [ModuleId.traveler, ModuleId.traveler]);
      expect(find.text('#4'), findsOneWidget);
      expect(find.textContaining('valid finished trips'), findsNothing);
      await tester.tap(find.text('Sample Player'));
      await tester.pumpAndSettle();
      expect(find.text('Position #4'), findsOneWidget);
      expect(find.textContaining('valid finished trips'), findsNothing);
    },
  );

  testWidgets(
    'existing typed named destination opens its category and returns Home',
    (tester) async {
      await tester.pumpWidget(const WayhunterApp());
      final context = tester.element(find.text('Choose a module'));
      const AppDestination.leaderboard(ModuleId.game).open(context);
      await tester.pumpAndSettle();
      expect(find.text('Game rankings'), findsOneWidget);
      expect(find.text('Rankings unavailable'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Choose a module'), findsOneWidget);
    },
  );
}

Widget _screen(LeaderboardPreviewLoader loader) => MaterialApp(
  home: Scaffold(
    body: LeaderboardHomeScreen(
      initialModule: ModuleId.traveler,
      previewLoader: loader,
    ),
  ),
);
