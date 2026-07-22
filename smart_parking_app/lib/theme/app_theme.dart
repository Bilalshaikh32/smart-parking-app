import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // Display/header text. Uses the platform's bundled sans-serif (Roboto on
  // Android) with tight tracking for a premium dashboard look — no network
  // font fetch, so the app renders identically with zero connectivity.
  static TextStyle display({
    double size = 16,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.foreground,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing ?? -0.3,
      );

  // LCD text, logs, timestamps, data readouts. 'monospace' resolves to a
  // bundled system monospace font (e.g. Droid Sans Mono on Android) —
  // no download required, works fully offline.
  static TextStyle mono({
    double size = 11,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.mutedForeground,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: 'monospace',
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  // Body text — platform default sans-serif.
  static TextStyle sans({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.foreground,
  }) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color);

  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: AppColors.primaryForeground,
          surface: AppColors.surface,
          error: AppColors.destructive,
        ),
      );

  /// Replicates the `.card-3d` neumorphic utility from styles.css:
  /// dual soft shadow (dark bottom-right, faint light top-left) + gradient.
  static BoxDecoration card3d({double radius = 24}) => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceRaised, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 30,
            offset: const Offset(10, 10),
          ),
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(-6, -6),
          ),
        ],
      );

  /// Glowing GREEN neumorphic card (Available)
  static BoxDecoration slot3dFree({double radius = 24}) => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceRaised, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 34,
            offset: const Offset(12, 12),
          ),
          BoxShadow(
            color: AppColors.available.withValues(alpha: 0.22),
            blurRadius: 40,
          ),
        ],
      );

  /// Inset RED glow neumorphic card (Occupied)
  static BoxDecoration slot3dOccupied({double radius = 24}) => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2B1113),
            Color(0xFF1A0C0E),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.occupied.withValues(alpha: 0.35),
            blurRadius: 30,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(6, 6),
          ),
        ],
      );

  /// Amber glow neumorphic card (Checking)
  static BoxDecoration slot3dChecking({double radius = 24}) => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2B2110),
            Color(0xFF1C160A),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.checking.withValues(alpha: 0.35),
            blurRadius: 30,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(6, 6),
          ),
        ],
      );
}