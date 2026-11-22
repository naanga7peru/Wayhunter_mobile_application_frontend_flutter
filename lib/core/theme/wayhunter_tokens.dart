import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

abstract final class WayhunterColors {
  static const ink = Color(0xFF153039);
  static const mutedInk = Color(0xFF33535B);
  static const scenicInk = Color(0xFFF6FBFC);
  static const primary = Color(0xFF126760);
  static const surface = Color(0xFFEDF5F2);
  static const glass = Color(0xCFEAF5F1);
  static const border = Color(0x59FFFFFF);
  static const danger = Color(0xFFC6424C);
  static const dangerInk = Color(0xFF9B2832);

  static Color moduleAccent(ModuleId module) => switch (module) {
        ModuleId.traveler => const Color(0xFF13BDEA),
        ModuleId.hunter => const Color(0xFF27C17C),
        ModuleId.game => const Color(0xFFA36AF0),
      };

  static Color moduleInk(ModuleId module) => switch (module) {
        ModuleId.traveler => const Color(0xFF1379AE),
        ModuleId.hunter => const Color(0xFF146C4E),
        ModuleId.game => const Color(0xFF6636B2),
      };
}

abstract final class WayhunterLayout {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const pagePadding = 20.0;
  static const cardRadius = 22.0;
  static const controlRadius = 16.0;
  static const minimumTap = 48.0;
  static const contentWidth = 560.0;

  static const gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF678C88), Color(0xFF9CB7B2), Color(0xFF628783)],
  );
}
