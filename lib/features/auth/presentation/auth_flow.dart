import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/features/auth/data/identity_api.dart';
import 'package:wayhunter_mobile/features/auth/presentation/views/otp_verification_screen.dart';
import 'package:wayhunter_mobile/features/auth/presentation/views/password_recovery_screens.dart';
import 'package:wayhunter_mobile/features/auth/presentation/views/register_screen.dart';
import 'package:wayhunter_mobile/features/auth/presentation/views/sign_in_screen.dart';

class AuthFlow extends StatefulWidget {
  const AuthFlow({
    super.key,
    required this.api,
    required this.session,
    this.onSignedIn,
    this.signInNotice,
  });

  final IdentityApi api;
  final SessionController session;
  final VoidCallback? onSignedIn;
  final String? signInNotice;

  /// Returns false when remote revocation failed but local clearing succeeded.
  /// A local storage failure propagates so the caller can retry clearing.
  static Future<bool> logout(IdentityApi api, SessionController session) async {
    if (session.accessToken == null) {
      await session.clear();
      return true;
    }
    try {
      await api.revokeSession();
      return true;
    } on ApiException {
      return false;
    } finally {
      await session.clear();
    }
  }

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool _signedIn = false;

  MaterialPageRoute<void> _page(WidgetBuilder builder) =>
      MaterialPageRoute<void>(builder: builder);

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _register() {
    Navigator.of(context).push(
      _page(
        (routeContext) => RegisterScreen(
          onSubmit: widget.api.register,
          onRegistered: (email) => Navigator.of(routeContext).pushReplacement(
            _page(
              (otpContext) => OtpVerificationScreen(
                email: email,
                initialCooldownSeconds: IdentityApi.otpCooldownSeconds,
                onVerify: (code) async {
                  try {
                    await widget.api.verifyOtp(email, code);
                    return OtpVerificationResult.verified;
                  } on ApiException catch (error) {
                    if (error.statusCode == 400) {
                      return OtpVerificationResult.invalidOrExpired;
                    }
                    rethrow;
                  }
                },
                onResend: () async {
                  await widget.api.resendOtp(email);
                  return true;
                },
                onVerified: () {
                  Navigator.of(otpContext).pop();
                  _notice('Email verified. Sign in to continue.');
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _recoverPassword() {
    Navigator.of(context).push(
      _page(
        (forgotContext) => WayhunterPageScaffold(
          appBar: AppBar(),
          body: ForgotPasswordScreen(
            api: widget.api,
            onContinue: (email) => Navigator.of(forgotContext).pushReplacement(
              _page(
                (resetContext) => WayhunterPageScaffold(
                  appBar: AppBar(),
                  body: ResetPasswordScreen(
                    api: widget.api,
                    email: email,
                    onReset: () {
                      Navigator.of(resetContext).pop();
                      _notice(
                        'Password reset. Sign in with your new password.',
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(String email, String password) async {
    final result = await widget.api.login(email, password);
    if (!mounted) return;
    if (!result.expiresAtUtc.isAfter(DateTime.now().toUtc())) {
      throw const ApiException(ApiError.invalidResponse);
    }
    await widget.session.authenticate(result.credential);
  }

  @override
  Widget build(BuildContext context) {
    if (_signedIn) return const Center(child: Text('Signed in successfully.'));
    return SignInScreen(
      onSignIn: _signIn,
      onSignedIn: widget.onSignedIn ?? () => setState(() => _signedIn = true),
      notice: widget.signInNotice,
      onRegister: _register,
      onForgotPassword: _recoverPassword,
    );
  }
}
