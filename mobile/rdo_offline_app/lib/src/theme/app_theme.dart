import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color supervisorLime = Color(0xFFCCFF00);
  static const Color supervisorDeep = Color(0xFF111111);
  static const Color supervisorTeal = Color(0xFF1E1E1E);
  static const Color supervisorAmber = Color(0xFFF9A81F);
  static const Color pageSurface = Color(0xFFFAFBFC);

  static ThemeData lightTheme() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: supervisorDeep,
      onPrimary: Colors.white,
      secondary: supervisorLime,
      onSecondary: Color(0xFF142900),
      error: Color(0xFFB42318),
      onError: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xFF0F172A),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: pageSurface,
      fontFamily: 'Poppins',
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: supervisorDeep,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: supervisorDeep,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: supervisorDeep,
          side: const BorderSide(color: Color(0xFFB2C3C8)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: const Color(0xFFEBEEF1),
        selectedColor: supervisorLime.withValues(alpha: 0.25),
        side: BorderSide.none,
        labelStyle: const TextStyle(
          color: supervisorDeep,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
