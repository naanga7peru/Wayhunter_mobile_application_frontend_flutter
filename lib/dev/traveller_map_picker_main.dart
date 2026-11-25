import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/testing.dart';
import 'package:wayhunter_mobile/app/bootstrap/foundation_services.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/network/package_http_transport.dart';
import 'package:wayhunter_mobile/core/services/android_location_services.dart';
import 'package:wayhunter_mobile/core/services/android_map_provider.dart';
import 'package:wayhunter_mobile/core/storage/credential_store.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_theme.dart';
import 'package:wayhunter_mobile/features/friends/presentation/friends_screen.dart';
import 'package:wayhunter_mobile/features/traveller/planning/data/trip_plans_api.dart';
import 'package:wayhunter_mobile/features/traveller/planning/presentation/trip_editor.dart';

void main() {
  if (!kDebugMode) return;

  const gps = AndroidLocationServices();
  final session = SessionController(const UnavailableCredentialStore());
  final api = ApiClient(
    baseUrl: null,
    transport: PackageHttpTransport(
      MockClient((_) {
        throw StateError('The offline picker has no backend.');
      }),
    ),
    tokens: session,
  );
  runApp(
    FoundationServices(
      api: api,
      session: session,
      maps: const AndroidMapProvider(),
      permissions: gps,
      location: gps,
      child: MaterialApp(
        theme: WayhunterTheme.light,
        home: Scaffold(
          appBar: AppBar(title: const Text('Offline Traveller picker')),
          body: TripEditor(api: TripPlansApi(api, session)),
        ),
        routes: {
          friendsRoute: (_) => Scaffold(
            appBar: AppBar(title: const Text('Friends')),
            body: const Center(child: Text('Friends requires a backend.')),
          ),
        },
      ),
    ),
  );
}
