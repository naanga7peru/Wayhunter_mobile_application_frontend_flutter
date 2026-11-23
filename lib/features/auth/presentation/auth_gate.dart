import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_controls.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_states.dart';
import 'package:wayhunter_mobile/features/auth/data/identity_api.dart';
import 'package:wayhunter_mobile/features/auth/presentation/auth_flow.dart';

enum _Phase {
  checking,
  readFailed,
  validationFailed,
  clearing,
  clearFailed,
  signedOut,
  authenticated,
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.api,
    required this.session,
    required this.authPage,
    required this.protectedApp,
  });

  final IdentityApi api;
  final SessionController session;
  final Widget Function(Widget body) authPage;
  final WidgetBuilder protectedApp;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  _Phase _phase = _Phase.checking;
  int _attempt = 0;
  String? _verifiedToken;
  bool _revocationFailed = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);
    _restore();
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    super.dispose();
  }

  bool _isCurrent(int attempt) => mounted && _attempt == attempt;

  void _sessionChanged() {
    if (_phase == _Phase.authenticated &&
        widget.session.accessToken != _verifiedToken) {
      setState(() {
        _verifiedToken = null;
        _phase = _Phase.signedOut;
      });
    }
  }

  Future<void> _restore() async {
    final attempt = ++_attempt;
    setState(() => _phase = _Phase.checking);
    try {
      await widget.session.restore();
    } on CredentialStorageException {
      if (_isCurrent(attempt)) setState(() => _phase = _Phase.readFailed);
      return;
    }
    if (_isCurrent(attempt)) await _validate();
  }

  Future<void> _validate() async {
    final attempt = ++_attempt;
    final session = widget.session;
    final token = session.accessToken;
    final userId = session.state.user?.id;
    if (token == null || userId == null) {
      setState(() => _phase = _Phase.signedOut);
      return;
    }

    setState(() => _phase = _Phase.checking);
    try {
      final serverUser = await widget.api.currentUser();
      if (!_isCurrent(attempt)) return;
      if (session.accessToken != token) {
        setState(() => _phase = _Phase.signedOut);
      } else if (serverUser.id == userId) {
        _openShell();
      } else {
        await _clearSession();
      }
    } on ApiException catch (error) {
      if (!_isCurrent(attempt)) return;
      if (session.accessToken != token) {
        setState(() => _phase = _Phase.signedOut);
      } else if (error.kind == ApiError.unauthorized ||
          error.kind == ApiError.forbidden) {
        await _clearSession();
      } else {
        setState(() => _phase = _Phase.validationFailed);
      }
    }
  }

  void _openShell() {
    final token = widget.session.accessToken;
    if (token == null ||
        widget.session.state.status != SessionStatus.authenticated) {
      return;
    }
    setState(() {
      _verifiedToken = token;
      _phase = _Phase.authenticated;
    });
  }

  Future<void> _clearSession({bool revoke = false}) async {
    if (_phase == _Phase.clearing) return;
    final attempt = ++_attempt;
    setState(() {
      _verifiedToken = null;
      _phase = _Phase.clearing;
    });
    try {
      if (revoke) {
        _revocationFailed = !await AuthFlow.logout(widget.api, widget.session);
      } else {
        await widget.session.clear();
      }
    } on CredentialStorageException {
      if (_isCurrent(attempt)) setState(() => _phase = _Phase.clearFailed);
      return;
    }
    if (_isCurrent(attempt)) setState(() => _phase = _Phase.signedOut);
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.authenticated) {
      return _SignOutScope(
        onSignOut: () => _clearSession(revoke: true),
        child: Builder(builder: widget.protectedApp),
      );
    }
    final body = switch (_phase) {
      _Phase.checking => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const WayhunterLoadingView(label: 'Checking your session'),
          WayhunterButton.secondary(
            label: 'Sign out',
            onPressed: () => _clearSession(revoke: true),
          ),
        ],
      ),
      _Phase.clearing => const WayhunterLoadingView(
        label: 'Clearing your session',
      ),
      _Phase.readFailed => WayhunterErrorView(
        title: 'Could not read secure session storage',
        onRetry: _restore,
      ),
      _Phase.validationFailed => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          WayhunterErrorView(
            title: 'Could not verify your session',
            message: 'Check your connection and try again.',
            onRetry: _validate,
          ),
          WayhunterButton.secondary(
            label: 'Sign out',
            onPressed: () => _clearSession(revoke: true),
          ),
        ],
      ),
      _Phase.clearFailed => WayhunterErrorView(
        title: 'Could not clear secure session storage',
        message: 'Retry to finish signing out.',
        onRetry: _clearSession,
      ),
      _Phase.signedOut => AuthFlow(
        api: widget.api,
        session: widget.session,
        onSignedIn: _openShell,
        signInNotice: _revocationFailed
            ? 'Signed out on this device. Server revocation could not be confirmed.'
            : null,
      ),
      _Phase.authenticated => throw StateError(
        'Authenticated shell handled above.',
      ),
    };
    return widget.authPage(SafeArea(child: body));
  }
}

class AuthSignOutTile extends StatelessWidget {
  const AuthSignOutTile({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SignOutScope>();
    if (scope == null) return const SizedBox.shrink();
    return ListTile(title: const Text('Sign out'), onTap: scope.onSignOut);
  }
}

class _SignOutScope extends InheritedWidget {
  const _SignOutScope({required this.onSignOut, required super.child});

  final VoidCallback onSignOut;

  @override
  bool updateShouldNotify(_SignOutScope oldWidget) =>
      onSignOut != oldWidget.onSignOut;
}
