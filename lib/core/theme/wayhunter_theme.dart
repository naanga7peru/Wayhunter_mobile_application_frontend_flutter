import 'package:flutter/material.dart';

class WayhunterTheme {
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
        cardTheme: const CardThemeData(
          color: Color(0xFF172635),
          margin: EdgeInsets.symmetric(vertical: 7),
        ),
      );
}
