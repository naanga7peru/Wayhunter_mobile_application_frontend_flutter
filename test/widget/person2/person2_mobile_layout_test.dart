import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/router/app_routes.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_theme.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_navigation.dart';
import 'package:wayhunter_mobile/features/hunter/domain/hunter_history.dart';
import 'package:wayhunter_mobile/features/hunter/presentation/hunter_screens.dart';
import 'package:wayhunter_mobile/features/wallet/domain/wallet_preview.dart';
import 'package:wayhunter_mobile/features/wallet/presentation/wallet_screens.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

void main() {
  testWidgets(
    'Hunter draft scrolls with the keyboard and survives review Back',
    (tester) async {
      await _pump(tester, const WayhunterApp());
      await _open(tester, hunterAddNewPlaceRoute);
      await _tap(tester, 'Review place details');
      expect(find.text('Enter a place name.'), findsOneWidget);
      expect(find.text('Enter a description.'), findsOneWidget);

      expect(find.text('Enter a place name.').hitTestable(), findsOneWidget);

      await _enter(tester, 'Place name', 'Coastal lookout');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await _enter(tester, 'Description', 'A lookout above the walking trail.');
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester.testTextInput.setClientArgs?['inputAction'],
        'TextInputAction.newline',
      );

      await _tap(tester, 'Review place details');
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('Coastal lookout'), findsOneWidget);
      final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit for review'),
      );
      expect(submit.onPressed, isNull);
      await _back(tester);
      expect(find.text('Coastal lookout'), findsOneWidget);
      expect(find.text('A lookout above the walking trail.'), findsOneWidget);
    },
  );

  testWidgets('My Hunts retries to an empty state at large text', (
    tester,
  ) async {
    final failedRead = Completer<List<HuntSummary>>();
    final history = _HuntHistory(failedRead.future);
    _setMobileViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: WayhunterTheme.light,
        home: Scaffold(body: MyHuntsScreen(history: history)),
      ),
    );
    expect(find.byType(WayhunterLoadingView), findsOneWidget);
    failedRead.completeError(StateError('Test read failed'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load hunts'), findsOneWidget);
    await _tap(tester, 'Retry');
    expect(find.text('No hunts yet'), findsOneWidget);
    expect(history.calls, 2);
    expect(find.text('Development demo data'), findsNothing);
  });

  testWidgets('Game draft remains editable at a narrow width and large text', (
    tester,
  ) async {
    await _pump(tester, const WayhunterApp());
    await _open(tester, createGameRoute);
    await _enter(tester, 'Game title', 'Trail puzzle');
    await _enter(tester, 'Description', 'Find the landmarks along the trail.');
    await _enter(tester, 'District', 'Galle');
    await _enter(tester, 'Play duration (minutes)', '0');
    expect(
      tester.testTextInput.setClientArgs?['inputType']['name'],
      'TextInputType.number',
    );
    await _tap(tester, 'Stages and Hints');
    expect(
      find.text('Enter a positive whole number of minutes.'),
      findsOneWidget,
    );
    await _enter(tester, 'Play duration (minutes)', '30');
    await _tap(tester, 'Stages and Hints');
    await _enter(tester, 'Stage 1 hint', 'Start at the gate.');
    await _tap(tester, 'Add stage');
    await _enter(tester, 'Stage 2 hint', 'Follow the path to the bridge.');
    await _tap(tester, 'Review Game');
    expect(find.text('Follow the path to the bridge.'), findsOneWidget);
    await _back(tester);
    expect(find.text('Follow the path to the bridge.'), findsOneWidget);
    await _back(tester);
    expect(find.text('Trail puzzle'), findsOneWidget);
  });

  testWidgets('Wallet pages scroll and Back returns to the Profile shortcut', (
    tester,
  ) async {
    await _pump(tester, const WayhunterApp());
    await _tap(tester, 'Profile');
    await _tap(tester, 'Wallet');
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.textContaining('Sample data'), findsNothing);
    for (final page in [
      'Transaction History',
      'Voucher Offers',
      'My Vouchers',
    ]) {
      await _tap(tester, page);
      expect(find.text(page), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await _back(tester);
    }
    await _back(tester);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
  });

  testWidgets(
    'DEMO game previews keep their label through challenge and result Back',
    (tester) async {
      await _pump(tester, const WayhunterApp());
      await _open(tester, playGameRoute);
      expect(find.text('Coastal Clues'), findsNothing);
      for (final action in [
        'Browse DEMO games',
        'Coastal Clues',
        'Accept Game',
        'Preview DEMO stage',
        'Browse DEMO results',
        'Expired',
      ]) {
        await _tap(tester, action);
        expect(find.textContaining('Preview only'), findsOneWidget);
      }
      await _back(tester);
      expect(find.text('Result previews'), findsOneWidget);
      await _back(tester);
      expect(find.text('Stage Challenge'), findsOneWidget);
    },
  );

  testWidgets(
    'Scaled leaderboard wraps categories and returns from preview details',
    (tester) async {
      await _pump(tester, const WayhunterApp());
      await _open(tester, AppRoutes.leaderboard, ModuleId.traveler);
      expect(find.text('Traveller rankings'), findsOneWidget);
      await _tap(tester, 'Hunter');
      expect(find.text('Hunter rankings'), findsOneWidget);
      await _tap(tester, 'Game');
      expect(find.text('Game rankings'), findsOneWidget);
      expect(find.text('Rankings unavailable'), findsOneWidget);
      await _tap(tester, 'Open DEMO preview');
      await _tap(tester, 'Sample Current User');
      expect(find.text('Ranking detail'), findsOneWidget);
      await _back(tester);
      expect(find.text('Game rankings'), findsOneWidget);
      await _tap(tester, 'Exit DEMO preview');
      expect(find.text('Sample Current User'), findsNothing);
    },
  );

  testWidgets(
    'Wallet DEMO redemption dialog remains scrollable at large text',
    (tester) async {
      await _pump(
        tester,
        MaterialApp(home: walletPreview(() async => demoBalance)),
      );
      await _tap(tester, 'Voucher Offers');
      await _tap(tester, demoOffers.first.title);
      await _tap(tester, 'Review redemption');
      expect(find.byType(AlertDialog), findsOneWidget);
      await _tap(tester, 'Close preview');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Eligible in this preview'), findsOneWidget);
    },
  );
}

class _HuntHistory implements HunterHistory {
  _HuntHistory(this.firstRead);

  final Future<List<HuntSummary>> firstRead;
  int calls = 0;

  @override
  Future<List<HuntSummary>> load() async {
    calls++;
    return calls == 1 ? firstRead : const [];
  }
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 640);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  _setMobileViewport(tester);
  await tester.pumpWidget(child);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _open(
  WidgetTester tester,
  String route, [
  Object? arguments,
]) async {
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .pushNamed<void>(route, arguments: arguments);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
