import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/network/api_http_client.dart';
import 'package:wayhunter_mobile/core/network/package_http_transport.dart';
import 'package:wayhunter_mobile/core/services/android_location_services.dart';
import 'package:wayhunter_mobile/core/services/android_map_provider.dart';
import 'package:wayhunter_mobile/core/services/device_interfaces.dart';
import 'package:wayhunter_mobile/core/storage/android_credential_store.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/features/traveller/active_trip/data/trip_recovery_store.dart';

class AppConfig {
  const AppConfig({this.environmentLabel = 'development', this.apiBaseUrl});

  static const _configuredEnvironment = String.fromEnvironment('WAYHUNTER_ENV');

  factory AppConfig.fromEnvironment() {
    const label = _configuredEnvironment;
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
  late final _locationServices =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? const AndroidLocationServices()
      : null;
  late final http.Client _http = createApiHttpClient(
    isDebug: kDebugMode,
    environment: AppConfig._configuredEnvironment,
    apiBaseUrl: widget.config.apiBaseUrl,
    certificateDerBase64: kDebugMode
        ? const String.fromEnvironment('WAYHUNTER_LOCAL_HTTPS_CERT_DER_BASE64')
        : '',
  );
  late final String? _storageNamespace =
      _locationServices != null && widget.config.apiBaseUrl != null
      ? base64Url.encode(
          utf8.encode(
            '${widget.config.environmentLabel}|${widget.config.apiBaseUrl}',
          ),
        )
      : null;
  late final TripRecoveryStore? _tripRecovery = _storageNamespace == null
      ? null
      : SecureTripRecoveryStore(_storageNamespace);
  late final SessionController _session = SessionController(_credentialStore());
  late final ApiClient _api = ApiClient(
    baseUrl: widget.config.apiBaseUrl,
    transport: PackageHttpTransport(_http),
    tokens: _session,
    captureUnauthorizedHandler: _session.captureUnauthorizedHandler,
  );

  CredentialStore _credentialStore() {
    final namespace = _storageNamespace;
    return namespace == null
        ? const UnavailableCredentialStore()
        : AndroidCredentialStore(namespace: namespace);
  }

  @override
  Widget build(BuildContext context) => FoundationServices(
    api: _api,
    session: _session,
    permissions: _locationServices ?? const UnavailableDeviceServices(),
    location: _locationServices ?? const UnavailableDeviceServices(),
    maps: const AndroidMapProvider(),
    tripRecovery: _tripRecovery,
    child: WayhunterApp.authenticated(
      environmentLabel: widget.config.environmentLabel,
      apiConfigured: widget.config.apiBaseUrl != null,
    ),
  );

  @override
  void dispose() {
    _http.close();
    _session.dispose();
    super.dispose();
  }
}
