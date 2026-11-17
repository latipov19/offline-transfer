import 'package:flutter/material.dart';

/// Shared colors and compact Material styling for transfer screens.
class AppTheme {
  AppTheme._();

  static Color color(BuildContext context, Color dark) {
    if (Theme.of(context).brightness == Brightness.dark) return dark;
    return switch (dark) {
      background => const Color(0xFFF5F8F6),
      surface => Colors.white,
      surfaceElevated => const Color(0xFFE9EFEB),
      textPrimary => const Color(0xFF15271E),
      textSecondary => const Color(0xFF495E52),
      textMuted => const Color(0xFF5D7165),
      textDisabled => const Color(0xFF87988E),
      primary ||
      primaryLight ||
      primaryDark ||
      success => const Color(0xFF19754F),
      accent || neonBlue => const Color(0xFF176E81),
      neonPink => const Color(0xFFA13760),
      warning => const Color(0xFF8A610D),
      error => const Color(0xFFB23333),
      border || divider => const Color(0x1F15271E),
      borderStrong => const Color(0x4015271E),
      _ => dark,
    };
  }

  // ── Color Palette ──────────────────────────────────────────────────────
  static const Color background = Color(0xFF101313);
  static const Color surface = Color(0xFF191D1D);
  static const Color surfaceElevated = Color(0xFF222828);
  static const Color surfaceGlass = Color(0x1AFFFFFF);

  static const Color primary = Color(0xFF80E0B1);
  static const Color primaryLight = Color(0xFFA8ECCB);
  static const Color primaryDark = Color(0xFF42AF80);
  static const Color primaryGlow = Color(0x0080E0B1);

  static const Color accent = Color(0xFF7CD4E4);
  static const Color accentGlow = Color(0x007CD4E4);

  // ── Ultra-Graphic Cyber & Neon Palette ─────────────────────────────────
  static const Color neonCyan = Color(0xFF7CD4E4);
  static const Color neonPurple = Color(0xFF80E0B1);
  static const Color neonPink = Color(0xFFF296B4);
  static const Color neonGreen = Color(0xFF80E0B1);
  static const Color neonBlue = Color(0xFF82B5F5);

  static const Color glassFill = Color(0x18FFFFFF);
  static const Color glassBorderColor = Color(0x28FFFFFF);
  static const Color glassHighlight = Color(0x45FFFFFF);

  static const Color success = Color(0xFF80E0B1);
  static const Color successGlow = Color(0x0080E0B1);
  static const Color warning = Color(0xFFEBC477);
  static const Color error = Color(0xFFF38989);
  static const Color errorGlow = Color(0x00F38989);

  static const Color textPrimary = Color(0xFFF2F6F4);
  static const Color textSecondary = Color(0xFFBAC5C0);
  static const Color textMuted = Color(0xFF8B9B94);
  static const Color textDisabled = Color(0xFF59665F);

  static const Color border = Color(0x1AFFFFFF);
  static const Color borderStrong = Color(0x33FFFFFF);
  static const Color divider = Color(0x0DFFFFFF);

  // ── Gradients ──────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyberGradient = LinearGradient(
    colors: [primary, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient neonPinkPurpleGradient = LinearGradient(
    colors: [accent, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassSpecularGradient = LinearGradient(
    colors: [Color(0x35FFFFFF), Color(0x05FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, Color(0xFF101313)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF191D1D), Color(0xFF191D1D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Dark Theme ─────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: background,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0,
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0,
        ),
        displaySmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          letterSpacing: 0,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textMuted,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      iconTheme: const IconThemeData(color: textSecondary),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceElevated,
      ),
    );
  }

  // ── Light Theme ────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: const Color(0xFFF5F8F6),
      primaryColor: const Color(0xFF19754F),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF19754F),
        brightness: Brightness.light,
        primary: const Color(0xFF19754F),
        secondary: const Color(0xFF176E81),
        surface: Colors.white,
        error: const Color(0xFFB23333),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: const Color(0xFF15271E),
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A2E),
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A2E),
        ),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF1A1A2E)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF666680)),
        bodySmall: TextStyle(fontSize: 12, color: Color(0xFF999EB5)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
        iconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0x1A000000)),
        ),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1A2E),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x1F15271E),
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: Color(0xFF495E52)),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}
