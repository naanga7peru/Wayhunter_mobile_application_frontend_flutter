enum WayhunterModule { traveler, hunter, game }

extension WayhunterModuleInfo on WayhunterModule {
  String get title => switch (this) {
        WayhunterModule.traveler => 'Traveler',
        WayhunterModule.hunter => 'Location Hunter',
        WayhunterModule.game => 'Game',
      };

  String get owner => switch (this) {
        WayhunterModule.traveler => 'M2 / M3',
        WayhunterModule.hunter => 'M4',
        WayhunterModule.game => 'M5',
      };
}
