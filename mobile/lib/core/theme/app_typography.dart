import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized typography system for TillPro app
/// Based on Material 3 standards with custom adjustments
class AppTypography {
  AppTypography._(); // Private constructor

  // ============= DISPLAY STYLES (Large, prominent text) =============
  static TextStyle displayLarge({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.bold,
    double letterSpacing = 0,
  }) =>
      TextStyle(
        fontSize: 32,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.2,
      );

  static TextStyle displayMedium({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.bold,
    double letterSpacing = 0,
  }) =>
      TextStyle(
        fontSize: 28,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.3,
      );

  static TextStyle displaySmall({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w600,
    double letterSpacing = 0,
  }) =>
      TextStyle(
        fontSize: 24,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.3,
      );

  // ============= HEADLINE STYLES (Section headers) =============
  static TextStyle headlineLarge({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.bold,
  }) =>
      TextStyle(
        fontSize: 22,
        fontWeight: weight,
        color: color,
        height: 1.3,
      );

  static TextStyle headlineMedium({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w600,
  }) =>
      TextStyle(
        fontSize: 18,
        fontWeight: weight,
        color: color,
        height: 1.4,
      );

  static TextStyle headlineSmall({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w600,
  }) =>
      TextStyle(
        fontSize: 16,
        fontWeight: weight,
        color: color,
        height: 1.4,
      );

  // ============= TITLE STYLES (Smaller than headlines) =============
  static TextStyle titleLarge({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w600,
  }) =>
      TextStyle(
        fontSize: 16,
        fontWeight: weight,
        color: color,
        height: 1.4,
      );

  static TextStyle titleMedium({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(
        fontSize: 14,
        fontWeight: weight,
        color: color,
        height: 1.4,
      );

  static TextStyle titleSmall({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(
        fontSize: 12,
        fontWeight: weight,
        color: color,
        height: 1.4,
      );

  // ============= BODY STYLES (Regular text content) =============
  static TextStyle bodyLarge({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(
        fontSize: 16,
        fontWeight: weight,
        color: color,
        height: 1.5,
      );

  static TextStyle bodyMedium({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(
        fontSize: 14,
        fontWeight: weight,
        color: color,
        height: 1.5,
      );

  static TextStyle bodySmall({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(
        fontSize: 12,
        fontWeight: weight,
        color: color,
        height: 1.5,
      );

  // ============= LABEL STYLES (Small, often uppercase) =============
  static TextStyle labelLarge({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(
        fontSize: 14,
        fontWeight: weight,
        color: color,
        letterSpacing: 0.5,
        height: 1.4,
      );

  static TextStyle labelMedium({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(
        fontSize: 12,
        fontWeight: weight,
        color: color,
        letterSpacing: 0.4,
        height: 1.4,
      );

  static TextStyle labelSmall({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(
        fontSize: 11,
        fontWeight: weight,
        color: color,
        letterSpacing: 0.3,
        height: 1.4,
      );

  // ============= SPECIALIZED STYLES =============

  /// Currency display (bold, large)
  static TextStyle currency({
    Color color = AppColors.primary,
    FontWeight weight = FontWeight.bold,
  }) =>
      TextStyle(
        fontSize: 24,
        fontWeight: weight,
        color: color,
        height: 1.2,
      );

  /// Secondary/muted text
  static TextStyle muted({
    Color color = AppColors.textSecondary,
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(
        fontSize: 14,
        fontWeight: weight,
        color: color,
        height: 1.5,
      );

  /// Disabled/placeholder text
  static TextStyle disabled({
    Color color = AppColors.textDisabled,
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(
        fontSize: 14,
        fontWeight: weight,
        color: color,
        height: 1.5,
      );

  /// Button text
  static TextStyle button({
    Color color = Colors.white,
    FontWeight weight = FontWeight.w600,
  }) =>
      TextStyle(
        fontSize: 14,
        fontWeight: weight,
        color: color,
        height: 1.4,
        letterSpacing: 0.3,
      );

  /// Badge/chip text
  static TextStyle badge({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w600,
  }) =>
      TextStyle(
        fontSize: 11,
        fontWeight: weight,
        color: color,
        height: 1.2,
      );

  /// Caption text for images, smaller metadata
  static TextStyle caption({
    Color color = AppColors.textTertiary,
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(
        fontSize: 12,
        fontWeight: weight,
        color: color,
        height: 1.4,
      );

  /// Monospace for receipt/code
  static TextStyle monospace({
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(
        fontSize: 12,
        fontWeight: weight,
        color: color,
        fontFamily: 'monospace',
        height: 1.5,
      );
}
