import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Segoe UI',
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF176B87),
      brightness: Brightness.light,
    ),
    cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF17202A),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Segoe UI',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF176B87),
      brightness: Brightness.dark,
    ),
    cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Color(0xFF111827),
      foregroundColor: Colors.white,
    ),
  );

  static ThemeData get theme => lightTheme;
}
