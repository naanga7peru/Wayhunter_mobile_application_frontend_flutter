import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/features/advertisements/data/home_advertisements_api.dart';
import 'package:wayhunter_mobile/features/advertisements/presentation/home_banner.dart';

final _ads = [_advertisement('One'), _advertisement('Two')];

HomeAdvertisement _advertisement(String title) => HomeAdvertisement(
  id: title,
  title: title,
  imageUrl: Uri.https('images.example.invalid', '/$title.png'),
  destinationUrl: null,
  startAtUtc: DateTime.utc(2026),
  endAtUtc: DateTime.utc(2027),
);

void main() {
  testWidgets('rotates advertisements every three seconds by default', (
    tester,
  ) async {
    await tester.pumpWidget(_app(HomeBanner(advertisements: _ads)));
    expect(find.text('One'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(find.text('One'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Two'), findsOneWidget);
  });

  testWidgets('uses a configurable rotation interval', (tester) async {
    await tester.pumpWidget(
      _app(
        HomeBanner(
          advertisements: _ads,
          rotationInterval: Duration(seconds: 1),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Two'), findsOneWidget);
  });

  testWidgets('refreshes every fifteen seconds by default', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(
        HomeBanner(
          advertisements: const [],
          loadAdvertisements: () async {
            calls++;
            return [_advertisement('Refreshed')];
          },
        ),
      ),
    );
    expect(calls, 0);
    await tester.pump(const Duration(seconds: 14));
    expect(calls, 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Refreshed'), findsOneWidget);
  });

  testWidgets('uses configurable refresh and avoids overlapping requests', (
    tester,
  ) async {
    final response = Completer<List<HomeAdvertisement>>();
    var calls = 0;
    await tester.pumpWidget(
      _app(
        HomeBanner(
          advertisements: const [],
          refreshInterval: const Duration(seconds: 2),
          loadAdvertisements: () {
            calls++;
            return response.future;
          },
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 6));
    expect(calls, 1);
    response.complete([_advertisement('Loaded')]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 2);
  });

  testWidgets('cancels timers and ignores late refresh after disposal', (
    tester,
  ) async {
    final response = Completer<List<HomeAdvertisement>>();
    var calls = 0;
    await tester.pumpWidget(
      _app(
        HomeBanner(
          advertisements: _ads,
          rotationInterval: const Duration(seconds: 1),
          refreshInterval: const Duration(seconds: 2),
          loadAdvertisements: () {
            calls++;
            return response.future;
          },
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete([_advertisement('Late')]);
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(calls, 1);
    expect(find.text('Late'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'retains a successful banner on failure and recovers from empty',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _app(
          HomeBanner(
            advertisements: [_advertisement('Initial')],
            loadAdvertisements: () async => switch (++calls) {
              1 => [_advertisement('Updated')],
              2 => throw StateError('offline'),
              3 => [],
              _ => _ads,
            },
          ),
        ),
      );

      for (final (call, title) in [
        (1, 'Updated'),
        (2, 'Updated'),
        (3, 'No active advertisements'),
        (4, 'One'),
      ]) {
        await tester.pump(const Duration(seconds: 15));
        await tester.pump();
        expect(calls, call);
        expect(find.text(title), findsOneWidget);
      }
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Two'), findsOneWidget);
    },
  );

  testWidgets('restores the source data and ignores a replaced loader result', (
    tester,
  ) async {
    final pending = Completer<List<HomeAdvertisement>>();
    await tester.pumpWidget(
      _app(
        HomeBanner(
          advertisements: _ads,
          loadAdvertisements: () => pending.future,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpWidget(
      _app(
        HomeBanner(
          advertisements: [_advertisement('Replacement')],
          loadAdvertisements: () async => [],
        ),
      ),
    );
    pending.complete([_advertisement('Superseded')]);
    await tester.pump();
    expect(find.text('Replacement'), findsOneWidget);
    expect(find.text('Superseded'), findsNothing);
  });

  testWidgets('pauses rotation while Android is backgrounded', (tester) async {
    await tester.pumpWidget(_app(HomeBanner(advertisements: _ads)));
    await tester.pump(const Duration(seconds: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('One'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Two'), findsOneWidget);
  });

  testWidgets('shows safe empty and API error fallbacks', (tester) async {
    await tester.pumpWidget(_app(const HomeBanner(advertisements: [])));
    expect(find.text('No active advertisements'), findsOneWidget);
    await tester.pumpWidget(
      _app(
        HomeBanner(
          advertisements: const [],
          refreshInterval: const Duration(seconds: 1),
          loadAdvertisements: () => Future.error(StateError('offline')),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('No active advertisements'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));
