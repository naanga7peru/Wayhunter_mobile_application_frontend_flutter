import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/features/games/presentation/game_playing.dart';

void main() {
  testWidgets('Discovery exposes no fixtures when previews are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PlayGameScreen())),
    );

    expect(find.text('Play Game'), findsOneWidget);
    expect(find.text('Live discovery unavailable'), findsOneWidget);
    expect(find.text('Browse DEMO games'), findsNothing);
  });

  testWidgets(
    'DEMO discovery opens the selected fixture and returns to the list',
    (tester) async {
      await _openDemoGames(tester);
      expect(find.text('Available Games'), findsOneWidget);
      expect(find.text('DEMO · Galle'), findsOneWidget);
      expect(find.text('DEMO · Kandy'), findsOneWidget);

      await _tap(tester, 'Garden Trail');
      _expectPreview('Game Details');
      expect(find.text('Garden Trail'), findsOneWidget);
      expect(
        find.text('Creators cannot play or win their own games.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('one eligible Admin-verified winner'),
        findsOneWidget,
      );
      expect(
        find.textContaining('creation and final player results separately'),
        findsOneWidget,
      );
      expect(find.textContaining('720 hours'), findsOneWidget);
      await _back(tester);
      _expectPreview('Available Games');
      await _back(tester);
      expect(find.text('Live discovery unavailable'), findsOneWidget);
    },
  );

  testWidgets('Acceptance and live proof remain unavailable in the preview', (
    tester,
  ) async {
    await _openStage(tester);
    expect(find.text('Stage 1 of 1'), findsOneWidget);
    expect(
      find.text('Look for a white tower overlooking the water.'),
      findsOneWidget,
    );

    await _tap(tester, 'Preview Live Camera Proof');
    _expectPreview('Live Camera Proof');
    expect(find.text('Live camera unavailable'), findsOneWidget);
    _expectDisabled(tester, 'Capture proof');
    expect(find.textContaining('Gallery'), findsNothing);
    expect(find.text('Pending Admin Verification'), findsNothing);

    await _back(tester);
    _expectPreview('Stage Challenge');
    await _back(tester);
    expect(find.text('Game acceptance unavailable'), findsOneWidget);
    _expectDisabled(tester, 'Start attempt');
  });

  testWidgets(
    'Result previews are individually reachable without submitting proof',
    (tester) async {
      await _openStage(tester);
      await _tap(tester, 'Browse DEMO results');
      _expectPreview('Result previews');

      const examples = {
        'Pending Admin Verification':
            'awaiting the separate Admin winner review',
        'Rejected':
            'Example reason: Proof did not show the requested landmark.',
        'Expired':
            'Players can no longer start, resume, or complete this game.',
        'Game Over': 'Three rejected proofs closed this example attempt.',
      };
      for (final MapEntry(key: title, value: message) in examples.entries) {
        await _tap(tester, title);
        _expectPreview(title);
        expect(find.textContaining(message), findsOneWidget);
        expect(find.byType(WayhunterButton), findsNothing);
        await _back(tester);
        _expectPreview('Result previews');
      }
    },
  );
}

Future<void> _openDemoGames(WidgetTester tester) async {
  await tester.pumpWidget(const WayhunterApp());
  await tester.tap(find.text('Game').first);
  await tester.pumpAndSettle();
  await _tap(tester, 'Play Game');
  await _tap(tester, 'Browse DEMO games');
}

Future<void> _openStage(WidgetTester tester) async {
  await _openDemoGames(tester);
  await _tap(tester, 'Coastal Clues');
  await _tap(tester, 'Accept Game');
  _expectPreview('Accept Game');
  await _tap(tester, 'Preview DEMO stage');
  _expectPreview('Stage Challenge');
}

void _expectPreview(String title) {
  expect(find.widgetWithText(AppBar, title), findsOneWidget);
  expect(find.text('DEMO · Preview only'), findsOneWidget);
}

void _expectDisabled(WidgetTester tester, String label) {
  final button = tester.widget<WayhunterButton>(
    find.widgetWithText(WayhunterButton, label),
  );
  expect(button.onPressed, isNull);
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}
