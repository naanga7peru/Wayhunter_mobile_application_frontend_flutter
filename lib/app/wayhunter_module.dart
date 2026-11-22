import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

export 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart'
    show ModuleId;

extension WayhunterModuleInfo on ModuleId {
  String get title => switch (this) {
        ModuleId.traveler => 'Traveler',
        ModuleId.hunter => 'Location Hunter',
        ModuleId.game => 'Game',
      };

  String get owner => switch (this) {
        ModuleId.traveler => 'M2 / M3',
        ModuleId.hunter => 'M4',
        ModuleId.game => 'M5',
      };
}
