import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_theme.dart';
import 'package:wayhunter_mobile/features/auth/presentation/views/otp_verification_screen.dart';
import 'package:wayhunter_mobile/features/auth/presentation/views/register_screen.dart';
import 'package:wayhunter_mobile/features/auth/presentation/views/sign_in_screen.dart';

Color _textColor(WidgetTester tester, String text) => tester
    .renderObject<RenderParagraph>(find.text(text, findRichText: true))
    .text
    .style!
    .color!;

void _expectContrast(Color foreground, Color background) {
  final luminances = [
    foreground.computeLuminance(),
    background.computeLuminance(),
  ]..sort();
  expect((luminances.last + .05) / (luminances.first + .05), greaterThan(4.5));
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Register uses readable text and validation on the dark route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: WayhunterTheme.light, home: const RegisterScreen()),
    );
    final background = WayhunterTheme.dark.scaffoldBackgroundColor;
    _expectContrast(_textColor(tester, 'Join Wayhunter'), background);
    _expectContrast(
      _textColor(tester, 'Start exploring Sri Lanka'),
      background,
    );
    _expectContrast(
      _textColor(tester, 'Full Name'),
      WayhunterTheme.dark.inputDecorationTheme.fillColor!,
    );

    await _tap(tester, find.widgetWithText(FilledButton, 'Create Account'));
    _expectContrast(_textColor(tester, 'Name is required'), background);
  });

  testWidgets(
    'Register toggles passwords independently and keeps the full name',
    (tester) async {
      String? submittedName;
      await tester.pumpWidget(
        MaterialApp(
          theme: WayhunterTheme.light,
          home: RegisterScreen(
            onSubmit: (name, _, _, _) async => submittedName = name,
          ),
        ),
      );
      final fields = find.byType(EditableText);
      bool obscured(int index) =>
          tester.widget<EditableText>(fields.at(index)).obscureText;
      expect(obscured(2), isTrue);
      expect(obscured(3), isTrue);
      await _tap(tester, find.byTooltip('Show password'));
      expect(obscured(2), isFalse);
      expect(obscured(3), isTrue);
      await _tap(tester, find.byTooltip('Show confirmation password'));
      await _tap(tester, find.byTooltip('Hide password'));
      expect(obscured(2), isTrue);
      expect(obscured(3), isFalse);

      const name = 'De Silva De Silva';
      for (final (index, value) in [
        (0, '  $name  '),
        (1, 'demo@example.invalid'),
        (2, 'Password123'),
        (3, 'Different123'),
      ]) {
        await tester.ensureVisible(fields.at(index));
        await tester.enterText(fields.at(index), value);
      }
      final button = find.widgetWithText(FilledButton, 'Create Account');
      await _tap(tester, button);
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(submittedName, isNull);
      await tester.enterText(fields.at(3), 'Password123');
      await _tap(tester, button);
      expect(submittedName, name);
    },
  );

  testWidgets('OTP hint, entry, and actions are readable in the light app', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WayhunterTheme.light,
        home: const OtpVerificationScreen(email: 'demo@example.invalid'),
      ),
    );
    final dark = WayhunterTheme.dark;
    final fill = dark.inputDecorationTheme.fillColor!;
    _expectContrast(
      _textColor(tester, 'OTP Verification'),
      dark.scaffoldBackgroundColor,
    );
    await _tap(tester, find.byType(TextField));
    _expectContrast(_textColor(tester, '000000'), fill);
    final editable = find.byType(EditableText);
    await tester.enterText(editable, '123');
    _expectContrast(tester.widget<EditableText>(editable).style.color!, fill);
    _expectContrast(_textColor(tester, 'Verify OTP'), dark.colorScheme.primary);
    _expectContrast(
      _textColor(tester, 'Resend OTP'),
      dark.scaffoldBackgroundColor,
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Verify OTP'));
    _expectContrast(
      _textColor(tester, 'Enter a valid 6-digit OTP'),
      dark.colorScheme.errorContainer,
    );
  });

  testWidgets(
    'Sign In shows the notice first and retry error beside the form',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const notice = 'Your session ended. Sign in again.';
      const error = 'Could not sign in with those credentials.';
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: WayhunterTheme.light,
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.5,
            child: child!,
          ),
          home: Scaffold(
            body: SignInScreen(
              notice: notice,
              onSignIn: (_, _) async {
                attempts++;
                throw const ApiException(ApiError.unauthorized);
              },
              onSignedIn: () {},
              onRegister: () {},
              onForgotPassword: () {},
            ),
          ),
        ),
      );
      final fields = find.byType(TextFormField);
      final button = find.widgetWithText(FilledButton, 'Sign In');
      expect(
        tester.getBottomLeft(find.text(notice)).dy,
        lessThan(tester.getTopLeft(fields.first).dy),
      );
      await _tap(tester, button);
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(attempts, 0);

      await tester.enterText(fields.first, 'demo@example.invalid');
      await tester.enterText(fields.last, 'Password123');
      final password = find.byType(EditableText).last;
      await _tap(tester, find.byTooltip('Show password'));
      expect(tester.widget<EditableText>(password).obscureText, isFalse);
      await _tap(tester, find.byTooltip('Hide password'));
      expect(tester.widget<EditableText>(password).obscureText, isTrue);

      await _tap(tester, button);
      expect(attempts, 1);
      final message = find.text(error);
      await tester.ensureVisible(message);
      await tester.pumpAndSettle();
      expect(message.hitTestable(), findsOneWidget);
      expect(
        tester.getBottomLeft(message).dy,
        lessThan(tester.getTopLeft(button).dy),
      );
      expect(find.text(notice), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
