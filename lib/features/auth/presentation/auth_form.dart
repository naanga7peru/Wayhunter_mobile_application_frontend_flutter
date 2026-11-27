import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_theme.dart';
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

class AuthDarkScaffold extends StatelessWidget {
  const AuthDarkScaffold({super.key, required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) => Theme(
    data: WayhunterTheme.dark,
    child: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    ),
  );
}

class AuthFeedback extends StatelessWidget {
  const AuthFeedback(this.message, {super.key, this.isError = true});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isError ? colors.errorContainer : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(WayhunterLayout.controlRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(WayhunterLayout.medium),
          child: Text(
            message,
            style: TextStyle(
              color: isError
                  ? colors.onErrorContainer
                  : colors.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

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
    this.notice,
  });

  final String title;
  final String submitLabel;
  final List<Widget Function(bool enabled)> fields;
  final Future<void> Function() onSubmit;
  final VoidCallback onSuccess;
  final List<Widget Function(bool enabled)> actions;
  final String Function(Object error) errorMessage;
  final String? notice;

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
                if (widget.notice case final notice?) ...[
                  const SizedBox(height: WayhunterLayout.medium),
                  AuthFeedback(notice, isError: false),
                ],
                for (final field in widget.fields) ...[
                  const SizedBox(height: WayhunterLayout.medium),
                  field(!_busy),
                ],
                if (_error case final message?) ...[
                  const SizedBox(height: WayhunterLayout.medium),
                  AuthFeedback(message),
                ],
                const SizedBox(height: WayhunterLayout.large),
                WayhunterButton.primary(
                  label: widget.submitLabel,
                  onPressed: _busy ? null : _submit,
                ),
                if (_busy) const WayhunterLoadingView(),
                for (final action in widget.actions) action(!_busy),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
