import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/features/auth/data/identity_api.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_form.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.api,
    required this.onContinue,
  });

  final IdentityApi api;
  final ValueChanged<String> onContinue;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  String? _submittedEmail;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_submittedEmail case final email?) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              IdentityApi.recoveryConfirmation,
              textAlign: TextAlign.center,
            ),
            WayhunterButton.primary(
              label: 'Enter recovery token',
              onPressed: () => widget.onContinue(email),
            ),
          ],
        ),
      );
    }
    return AuthForm(
      title: 'Forgot Password',
      submitLabel: 'Send reset instructions',
      fields: [
        (enabled) => WayhunterTextField(
          label: 'Email',
          controller: _email,
          enabled: enabled,
          keyboardType: TextInputType.emailAddress,
          validator: validateAuthEmail,
        ),
      ],
      onSubmit: () => widget.api.forgotPassword(_email.text.trim()),
      onSuccess: () => setState(() => _submittedEmail = _email.text.trim()),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.api,
    required this.email,
    required this.onReset,
  });

  final IdentityApi api;
  final String email;
  final VoidCallback onReset;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthForm(
    title: 'Reset Password',
    submitLabel: 'Reset Password',
    fields: [
      (enabled) => WayhunterTextField(
        label: 'Recovery token',
        controller: _token,
        enabled: enabled,
        obscureText: true,
        validator: (value) => value?.trim().isNotEmpty == true
            ? null
            : 'Enter your recovery token',
      ),
      (enabled) => WayhunterTextField(
        label: 'New password',
        controller: _password,
        enabled: enabled,
        obscureText: true,
        validator: (value) =>
            (value?.length ?? 0) >= 8 ? null : 'Use at least 8 characters',
      ),
      (enabled) => WayhunterTextField(
        label: 'Confirm new password',
        controller: _confirmation,
        enabled: enabled,
        obscureText: true,
        validator: (value) =>
            value == _password.text ? null : 'Passwords do not match',
      ),
    ],
    onSubmit: () => widget.api.resetPassword(
      widget.email,
      _token.text.trim(),
      _password.text,
      _confirmation.text,
    ),
    onSuccess: widget.onReset,
    errorMessage: (error) => switch (error) {
      ApiException(statusCode: 400) =>
        'The recovery token is invalid or expired.',
      _ => authErrorMessage(error),
    },
  );
}
