import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // prevent instantiation

  // --- Light theme ---
  static const Color primary = Color(0xFF6C63FF);       // Vibrant purple
  static const Color secondary = Color(0xFF00BFA6);     // Teal accent
  static const Color accent = Color(0xFFFF6584);        // Coral / CTA
  static const Color background = Color(0xFFF7F8FB);    // Soft off-white
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFFF5252);

  // Text (light)
  static const Color textPrimary = Color(0xFF0F1724);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // --- Dark theme ---
  static const Color primaryDark = Color(0xFF8B7FFF);
  static const Color secondaryDark = Color(0xFF3DD6B8);
  static const Color accentDark = Color(0xFFFF7A9A);
  static const Color backgroundDark = Color(0xFF0B1020);
  static const Color surfaceDark = Color(0xFF101426);
  static const Color errorDark = Color(0xFFFF6B6B);

  // Text (dark)
  static const Color textPrimaryDark = Color(0xFFE6EEF8);
  static const Color textSecondaryDark = Color(0xFF98A0B3);
  static const Color textHintDark = Color(0xFF6B7280);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Utility / accents
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF8B7FFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF6584), Color(0xFFFF7A9A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color divider = Color(0xFFE6E9F2);
  static const Color dividerDark = Color(0xFF1F2433);
}
