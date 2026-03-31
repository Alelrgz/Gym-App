import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFF0A0A0A);
  static const surface = Color(0xFF161616);
  static const elevated = Color(0xFF111111);
  static const primary = Color(0xFFFF8C00);
  static const primaryHover = Color(0xFFE07A00);
  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0x8CFFFFFF); // 55% white
  static const textTertiary = Color(0x55FFFFFF); // 33% white
  static const border = Color(0x0DFFFFFF); // 5% white
  static const borderLight = Color(0x14FFFFFF); // 8% white
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFFACC15);
}

/// Standard design tokens — use these for consistent styling across the app.
class AppRadius {
  static const double card = 20;      // Main cards, sections
  static const double button = 14;    // Buttons, inputs
  static const double chip = 10;      // Chips, badges, small elements
  static const double pill = 50;      // Fully rounded pills
}

/// Standard animation durations and curves.
class AppAnim {
  // Durations
  static const fast = Duration(milliseconds: 200);     // toggles, expand/collapse, highlights
  static const medium = Duration(milliseconds: 300);   // page transitions, tab switches
  static const dialog = Duration(milliseconds: 250);   // dialogs, popups, zoom overlays

  // Curves
  static const curve = Curves.easeInOut;               // default for fast animations
  static const pageCurve = Curves.easeOutCubic;        // page transitions, swipes

  /// Standard page transition (slide from bottom)
  static Route<T> pageRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: medium,
      reverseTransitionDuration: medium,
      transitionsBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: pageCurve)),
          child: child,
        );
      },
    );
  }

  /// Standard dialog/overlay transition (scale + fade zoom)
  static Route<T> dialogRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: dialog,
      reverseTransitionDuration: dialog,
      transitionsBuilder: (_, anim, __, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }
}

class AppCard {
  /// Standard card decoration — no border
  static BoxDecoration decoration({Color? color, double? radius}) => BoxDecoration(
    color: color ?? Colors.white.withValues(alpha: 0.04),
    borderRadius: BorderRadius.circular(radius ?? AppRadius.card),
  );

  /// Card with subtle border
  static BoxDecoration bordered({Color? color, double? radius}) => BoxDecoration(
    color: color ?? Colors.white.withValues(alpha: 0.04),
    borderRadius: BorderRadius.circular(radius ?? AppRadius.card),
    border: Border.all(color: AppColors.borderLight),
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900),
          displayMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
          headlineLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
          bodySmall: TextStyle(color: AppColors.textTertiary),
          labelLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textTertiary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Glass-morphism decoration for containers
class GlassDecoration {
  static BoxDecoration card({double opacity = 0.03, double borderRadius = 20}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  static BoxDecoration primary({double borderRadius = 20}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.02),
        ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  static BoxDecoration accent({double borderRadius = 20}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary.withValues(alpha: 0.10),
          AppColors.primary.withValues(alpha: 0.03),
        ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }
}
