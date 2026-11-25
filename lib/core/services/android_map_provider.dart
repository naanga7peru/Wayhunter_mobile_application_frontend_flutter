import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wayhunter_mobile/core/services/device_interfaces.dart';

class AndroidMapProvider implements MapProvider {
  const AndroidMapProvider();

  static const _configuration = MethodChannel('wayhunter/maps_smoke');

  @override
  Future<MapProviderStatus> availability() async {
    // The existing SDK key and configuration channel are debug-only.
    if (!kDebugMode ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return MapProviderStatus.unavailable;
    }
    return await _configuration.invokeMethod<bool>('isConfigured') == true
        ? MapProviderStatus.available
        : MapProviderStatus.unavailable;
  }
}
