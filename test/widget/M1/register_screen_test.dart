
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/features/auth/presentation/views/register_screen.dart';

void main() {
  Future<void> openRegisterScreen(
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );
  }

  Future<void> fillField(
    WidgetTester tester,
    int index,
    String value,
  ) async {
    final field = find.byType(TextFormField).at(index);

    await tester.ensureVisible(field);
    await tester.enterText(field, value);
  }

  Future<void> submitForm(
    WidgetTester tester,
  ) async {
    final button = find.widgetWithText(
      FilledButton,
      'Create Account',
    );

    await tester.ensureVisible(button);
    await tester.pumpAndSettle();

    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Empty registration shows required errors',
    (tester) async {
      await openRegisterScreen(tester);
      await submitForm(tester);

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('Confirm your password'), findsOneWidget);
    },
  );

  testWidgets(
    'Invalid email shows validation error',
    (tester) async {
      await openRegisterScreen(tester);

      await fillField(tester, 0, 'Demo Traveler');
      await fillField(tester, 1, 'wrong-email');
      await fillField(tester, 2, 'Password123');
      await fillField(tester, 3, 'Password123');

      await submitForm(tester);

      expect(
        find.text('Enter a valid email'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Short password is rejected',
    (tester) async {
      await openRegisterScreen(tester);

      await fillField(tester, 0, 'Demo Traveler');
      await fillField(tester, 1, 'demo@example.com');
      await fillField(tester, 2, 'abc');
      await fillField(tester, 3, 'abc');

      await submitForm(tester);

      expect(
        find.text('Use at least 8 characters'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Password mismatch is rejected',
    (tester) async {
      await openRegisterScreen(tester);

      await fillField(tester, 0, 'Demo Traveler');
      await fillField(tester, 1, 'demo@example.com');
      await fillField(tester, 2, 'Password123');
      await fillField(tester, 3, 'Different123');

      await submitForm(tester);

      expect(
        find.text('Passwords do not match'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Valid registration shows API pending message',
    (tester) async {
      await openRegisterScreen(tester);

      await fillField(tester, 0, 'Demo Traveler');
      await fillField(tester, 1, 'demo@example.com');
      await fillField(tester, 2, 'Password123');
      await fillField(tester, 3, 'Password123');

      await submitForm(tester);

      expect(
        find.text(
          'Form valid. Registration API not connected yet.',
        ),
        findsOneWidget,
      );
    },
  );
}
