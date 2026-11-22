import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/l10n/wayhunter_strings.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_theme.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';

Widget host(Widget child) => MaterialApp(
      theme: WayhunterTheme.light,
      home: WayhunterPageScaffold(body: child),
    );

void main() {
  test('shared strings resolve Tamil and Sinhala and fall back to English', () {
    final english = WayhunterStrings.forLocale(const Locale('en'));
    final tamil = WayhunterStrings.forLocale(const Locale('ta'));
    final sinhala = WayhunterStrings.forLocale(const Locale('si'));
    expect(
        WayhunterStrings.supportedLocales.map((locale) => locale.languageCode),
        ['en', 'ta', 'si']);
    expect(WayhunterStrings.forLocale(const Locale('ta', 'LK')), same(tamil));
    expect(WayhunterStrings.forLocale(const Locale('si', 'LK')), same(sinhala));
    expect(tamil.retry, matches(RegExp(r'[\u0B80-\u0BFF]')));
    expect(sinhala.retry, matches(RegExp(r'[\u0D80-\u0DFF]')));
    expect(WayhunterStrings.forLocale(const Locale('fr')), same(english));
  });

  testWidgets('error view invokes the caller retry once per tap',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(host(WayhunterErrorView(
      title: 'Could not load',
      onRetry: () => retries++,
    )));
    expect(find.text('Could not load'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('confirmation returns cancel, explicit confirm and dismiss',
      (tester) async {
    bool? result;
    await tester.pumpWidget(host(Builder(
      builder: (context) => Center(
        child: WayhunterButton.primary(
          label: 'Open dialog',
          onPressed: () async {
            result = await showWayhunterConfirmation(
              context,
              title: 'Clear draft?',
              message: 'The draft will be removed.',
              destructive: true,
            );
          },
        ),
      ),
    )));
    for (final (label, expected) in [('Cancel', false), ('Confirm', true)]) {
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(result, expected);
    }
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('text field forwards validation and edits', (tester) async {
    final formKey = GlobalKey<FormState>();
    String? edited;
    await tester.pumpWidget(host(Center(
      child: Form(
        key: formKey,
        child: WayhunterTextField(
          label: 'Name',
          validator: (text) => (text?.isEmpty ?? true) ? 'Enter a name' : null,
          onChanged: (text) => edited = text,
        ),
      ),
    )));
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Nila');
    expect(formKey.currentState!.validate(), isTrue);
    expect(edited, 'Nila');
  });

  testWidgets('empty, loading and unavailable views show distinct states',
      (tester) async {
    await tester
        .pumpWidget(host(const WayhunterEmptyView(title: 'No entries')));
    expect(find.text('No entries'), findsOneWidget);

    await tester
        .pumpWidget(host(const WayhunterLoadingView(label: 'Loading entries')));
    expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .semanticsLabel,
        'Loading entries');

    await tester.pumpWidget(host(const WayhunterUnavailableView()));
    expect(find.text('This destination is unavailable.'), findsOneWidget);
  });

  testWidgets('large text stays usable on a narrow Android-sized viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const WayhunterApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Game'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Starter placeholder'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(host(const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: WayhunterStatusIndicator(
          label: 'Waiting for a review from the team',
          tone: WayhunterStatusTone.warning,
        ),
      ),
    )));
    expect(find.text('Waiting for a review from the team'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
