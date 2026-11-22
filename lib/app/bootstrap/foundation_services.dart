import 'package:flutter/widgets.dart';
import 'package:wayhunter_mobile/core/auth/session_controller.dart';
import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/core/services/device_interfaces.dart';

class FoundationServices extends InheritedWidget {
  const FoundationServices({
    super.key,
    required this.api,
    required this.session,
    this.permissions = const UnavailableDeviceServices(),
    this.location = const UnavailableDeviceServices(),
    this.maps = const UnavailableDeviceServices(),
    this.capture = const UnavailableDeviceServices(),
    this.uploads = const UnavailableDeviceServices(),
    required super.child,
  });

  final ApiClient api;
  final SessionController session;
  final DevicePermissions permissions;
  final CurrentLocation location;
  final MapProvider maps;
  final LiveMediaCapture capture;
  final MediaUploadMonitor uploads;

  static FoundationServices of(BuildContext context) {
    final services = context
        .dependOnInheritedWidgetOfExactType<FoundationServices>();
    if (services == null) {
      throw StateError('Foundation services are not configured.');
    }
    return services;
  }

  @override
  bool updateShouldNotify(FoundationServices oldWidget) =>
      api != oldWidget.api ||
      session != oldWidget.session ||
      permissions != oldWidget.permissions ||
      location != oldWidget.location ||
      maps != oldWidget.maps ||
      capture != oldWidget.capture ||
      uploads != oldWidget.uploads;
}
