
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/features/auth/presentation/views/otp_verification_screen.dart';

void main() {
  Future<void> openOtpScreen(
    WidgetTester tester, {
    Future<OtpVerificationResult> Function(String)? onVerify,
    Future<bool> Function()? onResend,
    int initialCooldownSeconds = 0,
    int resendCooldownSeconds = 60,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OtpVerificationScreen(
          email: 'demo@example.com',
          onVerify: onVerify,
          onResend: onResend,
          initialCooldownSeconds: initialCooldownSeconds,
          resendCooldownSeconds: resendCooldownSeconds,
        ),
      ),
    );
  }

  Future<void> enterAndVerify(
    WidgetTester tester,
    String otp,
  ) async {
    await tester.enterText(
      find.byType(TextField),
      otp,
    );

    final verifyButton = find.widgetWithText(
      FilledButton,
      'Verify OTP',
    );

    await tester.ensureVisible(verifyButton);
    await tester.tap(verifyButton);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'OTP screen displays email address',
    (tester) async {
      await openOtpScreen(tester);

      expect(
        find.textContaining('demo@example.com'),
        findsOneWidget,
      );

      expect(
        find.text('OTP Verification'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Invalid OTP should show validation error',
    (tester) async {
      await openOtpScreen(tester);

      await enterAndVerify(tester, '123');

      expect(
        find.text('Enter a valid 6-digit OTP'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Wrong OTP should show error message',
    (tester) async {
      String? receivedCode;

      await openOtpScreen(
        tester,
        onVerify: (code) async {
          receivedCode = code;
          return OtpVerificationResult.wrongCode;
        },
      );

      await enterAndVerify(tester, '123456');

      expect(receivedCode, '123456');

      expect(
        find.text('Incorrect OTP. Please try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Expired OTP should show expiry message',
    (tester) async {
      await openOtpScreen(
        tester,
        onVerify: (code) async {
          return OtpVerificationResult.expired;
        },
      );

      await enterAndVerify(tester, '123456');

      expect(
        find.text('OTP expired. Request a new code.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Network failure should show retry message',
    (tester) async {
      await openOtpScreen(
        tester,
        onVerify: (code) async {
          return OtpVerificationResult.networkError;
        },
      );

      await enterAndVerify(tester, '123456');

      expect(
        find.text('Network error. Please retry.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Successful OTP should show success message',
    (tester) async {
      await openOtpScreen(
        tester,
        onVerify: (code) async {
          return OtpVerificationResult.verified;
        },
      );

      await enterAndVerify(tester, '123456');

      expect(
        find.text('Email verified successfully'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Resend countdown should block early resend',
    (tester) async {
      var resendCount = 0;

      await openOtpScreen(
        tester,
        initialCooldownSeconds: 2,
        resendCooldownSeconds: 2,
        onResend: () async {
          resendCount++;
          return true;
        },
      );

      expect(
        find.text('Resend code in 2 seconds'),
        findsOneWidget,
      );

      expect(
        find.text('Resend OTP'),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Resend code in 1 second'),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 1));

      final resendButton = find.text('Resend OTP');

      expect(resendButton, findsOneWidget);

      await tester.ensureVisible(resendButton);
      await tester.tap(resendButton);
      await tester.pumpAndSettle();

      expect(resendCount, 1);

      expect(
        find.text('A new OTP has been requested'),
        findsOneWidget,
      );

      expect(
        find.text('Resend code in 2 seconds'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Resend failure should show error',
    (tester) async {
      await openOtpScreen(
        tester,
        onResend: () async => false,
      );

      final resendButton = find.text('Resend OTP');

      await tester.ensureVisible(resendButton);
      await tester.tap(resendButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Could not resend OTP. Please retry.'),
        findsOneWidget,
      );
    },
  );
}
