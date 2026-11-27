import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';

class WayhunterTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: WayhunterColors.primary)
          .copyWith(
            primary: WayhunterColors.primary,
            surface: WayhunterColors.surface,
            onSurface: WayhunterColors.ink,
            onSurfaceVariant: WayhunterColors.mutedInk,
            error: WayhunterColors.dangerInk,
          ),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(WayhunterLayout.controlRadius),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(WayhunterLayout.controlRadius),
      borderSide: const BorderSide(color: WayhunterColors.mutedInk),
    );
    return base.copyWith(
      scaffoldBackgroundColor: WayhunterColors.surface,
      textTheme: base.textTheme
          .apply(
            bodyColor: WayhunterColors.ink,
            displayColor: WayhunterColors.ink,
          )
          .copyWith(
            headlineMedium: const TextStyle(
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: WayhunterColors.ink,
            ),
            titleLarge: const TextStyle(
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: WayhunterColors.ink,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: WayhunterColors.ink,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: WayhunterColors.surface,
        foregroundColor: WayhunterColors.ink,
        centerTitle: false,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: WayhunterColors.surface,
        indicatorColor: Color(0xFFCCE5DD),
      ),
      cardTheme: CardThemeData(
        color: WayhunterColors.glass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WayhunterLayout.cardRadius),
          side: const BorderSide(color: WayhunterColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WayhunterColors.surface,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        contentPadding: const EdgeInsets.all(WayhunterLayout.large),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(
            WayhunterLayout.minimumTap,
            WayhunterLayout.minimumTap,
          ),
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
            WayhunterLayout.minimumTap,
            WayhunterLayout.minimumTap,
          ),
          shape: controlShape,
        ),
      ),
    );
  }

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF17C8E6),
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0A1420),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A1420),
      centerTitle: false,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF172635),
      border: OutlineInputBorder(),
      errorMaxLines: 3,
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF172635),
      margin: EdgeInsets.symmetric(vertical: 7),
    ),
  );
}
