import 'package:flutter/material.dart';

/// KalaSetu design tokens — warm, earthy, craft-inspired palette.
/// Big tap targets + high contrast for low-literacy accessibility.
class AppColors {
  static const primary = Color(0xFFB5451B); // terracotta
  static const primaryDark = Color(0xFF8A2E10);
  static const accent = Color(0xFFE9A319); // haldi/marigold
  static const bg = Color(0xFFFBF7F0); // warm ivory
  static const surface = Colors.white;
  static const text = Color(0xFF2B2118);
  static const muted = Color(0xFF7A6E60);
  static const success = Color(0xFF2E7D5B);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56), // big tap target
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
