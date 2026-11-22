import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/network/package_http_transport.dart';
import 'package:wayhunter_mobile/core/storage/android_credential_store.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';

class AppConfig {
  const AppConfig({this.environmentLabel = 'development', this.apiBaseUrl});

  factory AppConfig.fromEnvironment() {
    const label = String.fromEnvironment(
      'WAYHUNTER_ENV',
      defaultValue: 'development',
    );
    const apiUrl = String.fromEnvironment('WAYHUNTER_API_BASE_URL');
    return AppConfig(
      environmentLabel: switch (label) {
        'development' || 'staging' || 'production' => label,
        _ => 'development',
      },
      apiBaseUrl: ApiClient.validatedBaseUrl(Uri.tryParse(apiUrl)),
    );
  }

  final String environmentLabel;
  final Uri? apiBaseUrl;
}

void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(_FoundationRoot(config: AppConfig.fromEnvironment()));
}

class _FoundationRoot extends StatefulWidget {
  const _FoundationRoot({required this.config});

  final AppConfig config;

  @override
  State<_FoundationRoot> createState() => _FoundationRootState();
}

class _FoundationRootState extends State<_FoundationRoot> {
  late final http.Client _http = http.Client();
  late final SessionController _session = SessionController(_credentialStore());
  late final ApiClient _api = ApiClient(
    baseUrl: widget.config.apiBaseUrl,
    transport: PackageHttpTransport(_http),
    tokens: _session,
  );

  CredentialStore _credentialStore() {
    final baseUrl = widget.config.apiBaseUrl;
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        baseUrl == null) {
      return const UnavailableCredentialStore();
    }
    final namespace = base64Url.encode(
      utf8.encode('${widget.config.environmentLabel}|$baseUrl'),
    );
    return AndroidCredentialStore(namespace: namespace);
  }

  @override
  Widget build(BuildContext context) => FoundationServices(
    api: _api,
    session: _session,
    child: WayhunterApp(environmentLabel: widget.config.environmentLabel),
  );

  @override
  void dispose() {
    _http.close();
    _session.dispose();
    super.dispose();
  }
}
