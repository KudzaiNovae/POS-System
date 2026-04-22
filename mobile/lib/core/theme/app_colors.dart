import 'package:flutter/material.dart';

/// Centralized color system for TillPro app
/// Using a modern indigo + slate palette with semantic colors
class AppColors {
  AppColors._(); // Private constructor

  // ============= PRIMARY COLOR =============
  /// Main brand color - Indigo
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryVeryLight = Color(0xFFEEF2FF);

  // ============= SECONDARY COLORS =============
  /// Success - Emerald
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xD4D4F9);
  static const Color successBg = Color(0xF0FDF4);

  /// Warning - Amber
  static const Color warning = Color(0xFFA16207);
  static const Color warningLight = Color(0xFFFCD34D);
  static const Color warningBg = Color(0xFFFEF3C7);

  /// Error - Red
  static const Color error = Color(0xDC2626);
  static const Color errorLight = Color(0xFFFCA5A5);
  static const Color errorBg = Color(0xFFFEE2E2);

  /// Info - Sky
  static const Color info = Color(0xFF0EA5E9);
  static const Color infoBg = Color(0xFFF0F9FF);

  // ============= NEUTRAL COLORS (Slate) =============
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // ============= SEMANTIC COLORS =============
  static const Color background = slate50;
  static const Color surface = Colors.white;
  static const Color surfaceAlt = slate100;
  static const Color surfaceHover = slate50;
  static const Color border = slate200;
  static const Color borderHeavy = slate300;
  static const Color divider = slate100;

  static const Color textPrimary = slate900;
  static const Color textSecondary = slate600;
  static const Color textTertiary = slate500;
  static const Color textDisabled = slate400;
  static const Color textOnPrimary = Colors.white;

  // ============= SPECIAL COLORS =============
  static const Color overlay = Color(0x1A000000); // 10% black
  static const Color shadow = Color(0x0A000000); // 4% black
  static const Color disabled = slate300;
  static const Color placeholder = slate400;

  // ============= STATUS COLORS =============
  static const Color outOfStock = error;
  static const Color lowStock = warning;
  static const Color inStock = success;

  static const Color pending = warningLight;
  static const Color completed = success;
  static const Color voided = slate400;
  static const Color failed = error;
  static const Color submitted = success;

  // ============= COLOR UTILITIES =============
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }

  static Color getStatusColor(String status) {
    return switch (status.toUpperCase()) {
      'COMPLETED' || 'SUBMITTED' => completed,
      'PENDING' => pending,
      'VOIDED' => voided,
      'FAILED' => failed,
      _ => slate400,
    };
  }

  static Color getStockStatusColor(num qty, num reorderLevel) {
    if (qty <= 0) return outOfStock;
    if (qty <= reorderLevel) return lowStock;
    return inStock;
  }

  static String getStockStatus(num qty, num reorderLevel) {
    if (qty <= 0) return 'Out';
    if (qty <= reorderLevel) return 'Low';
    return 'OK';
  }
}
