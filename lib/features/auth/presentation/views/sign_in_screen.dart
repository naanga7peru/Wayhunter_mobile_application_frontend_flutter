import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_form.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.onSignIn,
    required this.onSignedIn,
    required this.onRegister,
    required this.onForgotPassword,
    this.notice,
  });

  final Future<void> Function(String email, String password) onSignIn;
  final VoidCallback onSignedIn;
  final VoidCallback onRegister;
  final VoidCallback onForgotPassword;
  final String? notice;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthForm(
    title: 'Sign In',
    submitLabel: 'Sign In',
    notice: widget.notice,
    fields: [
      (enabled) => WayhunterTextField(
        label: 'Email',
        controller: _email,
        enabled: enabled,
        keyboardType: TextInputType.emailAddress,
        validator: validateAuthEmail,
      ),
      (enabled) => TextFormField(
        controller: _password,
        enabled: enabled,
        obscureText: !_showPassword,
        decoration: InputDecoration(
          labelText: 'Password',
          suffixIcon: IconButton(
            tooltip: _showPassword ? 'Hide password' : 'Show password',
            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
            onPressed: enabled
                ? () => setState(() => _showPassword = !_showPassword)
                : null,
          ),
        ),
        validator: (value) =>
            value?.isNotEmpty == true ? null : 'Enter your password',
      ),
    ],
    onSubmit: () => widget.onSignIn(_email.text.trim(), _password.text),
    onSuccess: () {
      _password.clear();
      setState(() => _showPassword = false);
      widget.onSignedIn();
    },
    errorMessage: (error) => switch (error) {
      ApiException(kind: ApiError.unauthorized) =>
        'Could not sign in with those credentials.',
      _ => authErrorMessage(error),
    },
    actions: [
      (enabled) => TextButton(
        onPressed: enabled ? widget.onRegister : null,
        child: const Text('Create Account'),
      ),
      (enabled) => TextButton(
        onPressed: enabled ? widget.onForgotPassword : null,
        child: const Text('Forgot Password'),
      ),
    ],
  );
}
