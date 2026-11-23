import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_page.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';

String? validateAuthEmail(String? value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Enter a valid email';

String authErrorMessage(Object error) => switch (error) {
  ApiException(statusCode: 429) => 'Too many requests. Wait and try again.',
  ApiException(kind: ApiError.unavailable) =>
    'Authentication is unavailable on this app configuration.',
  ApiException(kind: ApiError.network || ApiError.timeout) =>
    'Could not reach Wayhunter. Try again.',
  CredentialStorageException() => 'Could not securely save your session.',
  SessionOperationSupersededException() =>
    'Sign-in was interrupted. Try again.',
  _ => 'Could not complete the request. Try again.',
};

class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.fields,
    required this.onSubmit,
    required this.onSuccess,
    this.actions = const [],
    this.errorMessage = authErrorMessage,
  });

  final String title;
  final String submitLabel;
  final List<Widget Function(bool enabled)> fields;
  final Future<void> Function() onSubmit;
  final VoidCallback onSuccess;
  final List<Widget Function(bool enabled)> actions;
  final String Function(Object error) errorMessage;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit();
      if (mounted) widget.onSuccess();
    } catch (error) {
      if (mounted) setState(() => _error = widget.errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(WayhunterLayout.pagePadding),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WayhunterHeader(title: widget.title),
                for (final field in widget.fields) ...[
                  const SizedBox(height: WayhunterLayout.medium),
                  field(!_busy),
                ],
                const SizedBox(height: WayhunterLayout.large),
                WayhunterButton.primary(
                  label: widget.submitLabel,
                  onPressed: _busy ? null : _submit,
                ),
                if (_busy) const WayhunterLoadingView(),
                if (_error case final message?)
                  Semantics(liveRegion: true, child: Text(message)),
                for (final action in widget.actions) action(!_busy),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
