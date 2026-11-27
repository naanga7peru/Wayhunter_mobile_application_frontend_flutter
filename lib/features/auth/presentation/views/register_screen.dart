import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_form.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.onSubmit, this.onRegistered});

  final Future<void> Function(
    String displayName,
    String email,
    String password,
    String confirmPassword,
  )?
  onSubmit;
  final ValueChanged<String>? onRegistered;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  String? _error;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _validateRegistration() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final submit = widget.onSubmit;
    if (submit != null) {
      final email = _emailController.text.trim();
      setState(() {
        _submitting = true;
        _error = null;
      });
      try {
        await submit(
          _nameController.text.trim(),
          email,
          _passwordController.text,
          _confirmController.text,
        );
        if (mounted) {
          _passwordController.clear();
          _confirmController.clear();
          widget.onRegistered?.call(email);
        }
      } catch (error) {
        if (mounted) setState(() => _error = authErrorMessage(error));
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Form valid. Registration API not connected yet.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthDarkScaffold(
      title: 'Create Account',
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.explore,
                      color: Color(0xFF17C8E6),
                      size: 52,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Join Wayhunter',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Start exploring Sri Lanka',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _nameController,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        final name = value?.trim() ?? '';

                        if (name.isEmpty) {
                          return 'Name is required';
                        }

                        if (name.length > 200) {
                          return 'Name is too long';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      enabled: !_submitting,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Email is required';
                        }

                        if (!_emailPattern.hasMatch(email)) {
                          return 'Enter a valid email';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      enabled: !_submitting,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'Hide password'
                              : 'Show password',
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: _submitting
                              ? null
                              : () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }

                        if (value.length < 8) {
                          return 'Use at least 8 characters';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirmController,
                      enabled: !_submitting,
                      obscureText: !_showConfirmPassword,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          tooltip: _showConfirmPassword
                              ? 'Hide confirmation password'
                              : 'Show confirmation password',
                          icon: Icon(
                            _showConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: _submitting
                              ? null
                              : () => setState(
                                  () => _showConfirmPassword =
                                      !_showConfirmPassword,
                                ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirm your password';
                        }

                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }

                        return null;
                      },
                    ),

                    if (_error case final message?) ...[
                      const SizedBox(height: 12),
                      AuthFeedback(message),
                    ],
                    const SizedBox(height: 24),

                    FilledButton(
                      onPressed: _submitting ? null : _validateRegistration,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          _submitting
                              ? 'Creating account...'
                              : 'Create Account',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
