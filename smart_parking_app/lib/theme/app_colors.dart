import 'package:flutter/material.dart';

/// Dark navy / charcoal dashboard palette.
/// Green = Available, Red = Occupied, Amber = Checking / gate movement,
/// Blue = Bluetooth accent. Status is always paired with an icon + text,
/// never color alone (accessibility requirement).
class AppColors {
  AppColors._();

  // Base surfaces
  static const Color background = Color(0xFF0A0E14);
  static const Color backgroundDark = Color(0xFF05070B);
  static const Color surface = Color(0xFF10151F);
  static const Color surfaceRaised = Color(0xFF171E2B);

  // Text
  static const Color foreground = Color(0xFFEDF1F7);
  static const Color mutedForeground = Color(0xFF8C97AB);

  // Status colors
  static const Color available = Color(0xFF34D399); // green
  static const Color availableForeground = Color(0xFF07281C);

  static const Color occupied = Color(0xFFF75555); // red
  static const Color occupiedForeground = Color(0xFF2B0808);

  static const Color checking = Color(0xFFF5A524); // amber
  static const Color checkingForeground = Color(0xFF2B1B02);

  static const Color unknown = Color(0xFF64748B); // slate/grey

  // Bluetooth / primary accent
  static const Color bluetooth = Color(0xFF3B9EFF); // blue
  static const Color bluetoothForeground = Color(0xFF071B2E);

  static const Color primary = bluetooth;
  static const Color primaryForeground = bluetoothForeground;
  static const Color destructive = occupied;
  static const Color destructiveForeground = occupiedForeground;
  static const Color free = available;
  static const Color freeForeground = availableForeground;

  static const Color border = Color(0xFF232B3B);

  static Color primaryAlpha(double opacity) => primary.withValues(alpha: opacity);
  static Color destructiveAlpha(double opacity) => destructive.withValues(alpha: opacity);
  static Color surfaceAlpha(double opacity) => surface.withValues(alpha: opacity);
  static Color freeAlpha(double opacity) => free.withValues(alpha: opacity);
  static Color availableAlpha(double opacity) => available.withValues(alpha: opacity);
  static Color occupiedAlpha(double opacity) => occupied.withValues(alpha: opacity);
  static Color checkingAlpha(double opacity) => checking.withValues(alpha: opacity);
  static Color bluetoothAlpha(double opacity) => bluetooth.withValues(alpha: opacity);
}
