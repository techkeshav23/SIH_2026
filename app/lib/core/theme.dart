import 'package:flutter/material.dart';

/// KalaSetu design system — "warm artisan craft": terracotta + haldi on a warm
/// cream canvas, indigo pops, soft tactile surfaces. Built for accessibility:
/// high contrast, big tap targets, generous spacing, clear hierarchy.
class AppColors {
  static const primary = Color(0xFFBE4A2F);    // terracotta
  static const primaryDark = Color(0xFF8F3620);
  static const accent = Color(0xFFE8A317);     // haldi / marigold
  static const indigo = Color(0xFF3B4A6B);     // deep indigo pop
  static const success = Color(0xFF2E7D5B);
  static const danger = Color(0xFFC0392B);

  static const bg = Color(0xFFFBF6EE);         // warm cream
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF4ECDF); // sand
  static const line = Color(0xFFEBE1D2);

  static const text = Color(0xFF2A2018);
  static const textSoft = Color(0xFF5C4F41);
  static const muted = Color(0xFF9A8B77);
}

/// Spacing scale (4-pt based).
class Gap {
  static const xs = SizedBox(height: 4, width: 4);
  static const s = SizedBox(height: 8, width: 8);
  static const m = SizedBox(height: 16, width: 16);
  static const l = SizedBox(height: 24, width: 24);
  static const xl = SizedBox(height: 40, width: 40);
}

class Radii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 30.0;
  static const pill = 999.0;
}

/// Design tokens for gradients & shadows used across the app.
class Decor {
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, Color(0xFFD9772E)],
  );

  static const warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8A317), Color(0xFFBE4A2F)],
  );

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: AppColors.primaryDark.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get lift => [
        BoxShadow(
          color: AppColors.primaryDark.withValues(alpha: 0.10),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      tertiary: AppColors.indigo,
      surface: AppColors.surface,
      error: AppColors.danger,
      brightness: Brightness.light,
    );

    const font = 'Roboto';
    final text = _textTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: font,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: AppColors.line, width: 1.4),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: const BorderSide(color: AppColors.line),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.muted),
        labelStyle: const TextStyle(color: AppColors.textSoft),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: const BorderSide(color: AppColors.line, width: 1.4),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: const BorderSide(color: AppColors.line, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
      ),

      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        side: BorderSide(color: AppColors.line),
        labelStyle: TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w600, fontSize: 12),
        shape: StadiumBorder(),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),

      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 24),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
    );
  }

  static TextTheme _textTheme() {
    const c = AppColors.text;
    return const TextTheme(
      displaySmall: TextStyle(color: c, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1),
      headlineMedium: TextStyle(color: c, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: AppColors.textSoft, fontSize: 15.5, height: 1.45),
      bodyMedium: TextStyle(color: AppColors.textSoft, fontSize: 14, height: 1.45),
      labelLarge: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
    );
  }
}
