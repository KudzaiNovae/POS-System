import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Centralized theme generation for TillPro app
class AppTheme {
  AppTheme._(); // Private constructor

  /// Generate the light theme for the app
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // ============= COLOR SCHEME =============
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: AppColors.surface,
        error: AppColors.error,
        errorContainer: AppColors.errorBg,
      ),

      // ============= TEXT THEME =============
      textTheme: _buildTextTheme(),

      // ============= APP BAR THEME =============
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.primary),
        titleTextStyle: AppTypography.headlineMedium(),
        toolbarHeight: AppSpacing.appBarHeight,
        toolbarTextStyle: AppTypography.bodyMedium(),
      ),

      // ============= NAVIGATION BAR THEME =============
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.textTertiary, size: 24);
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppTypography.labelSmall(weight: FontWeight.w600);
          }
          return AppTypography.labelSmall();
        }),
        indicatorColor: AppColors.primaryVeryLight,
        height: AppSpacing.bottomNavHeight,
      ),

      // ============= CARD THEME =============
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
        color: AppColors.surface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // ============= BUTTON THEMES =============
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: AppTypography.button(),
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeightMd),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: AppTypography.button(color: AppColors.primary),
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeightMd),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: AppTypography.button(color: AppColors.primary),
        ),
      ),

      // ============= INPUT DECORATION THEME =============
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.disabled),
        ),
        hintStyle: AppTypography.bodyMedium(color: AppColors.placeholder),
        labelStyle: AppTypography.bodyMedium(color: AppColors.textSecondary),
        helperStyle: AppTypography.bodySmall(color: AppColors.textTertiary),
        errorStyle: AppTypography.bodySmall(color: AppColors.error),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),

      // ============= CHIP THEME =============
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        selectedColor: AppColors.primaryVeryLight,
        secondarySelectedColor: AppColors.primaryVeryLight,
        labelStyle: AppTypography.labelMedium(),
        secondaryLabelStyle: AppTypography.labelMedium(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        side: BorderSide.none,
      ),

      // ============= DIALOG THEME =============
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        elevation: 0,
        titleTextStyle: AppTypography.headlineMedium(),
        contentTextStyle: AppTypography.bodyMedium(),
      ),

      // ============= SNACKBAR THEME =============
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.slate800,
        contentTextStyle: AppTypography.bodyMedium(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        elevation: 4,
        behavior: SnackBarBehavior.floating,
      ),

      // ============= BOTTOM SHEET THEME =============
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
      ),

      // ============= ICON THEME =============
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: AppSpacing.iconSizeMd,
      ),

      // ============= PROGRESS INDICATORS =============
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        circularTrackColor: AppColors.surfaceAlt,
        linearMinHeight: 4,
        linearTrackColor: AppColors.surfaceAlt,
      ),

      // ============= SWITCH THEME =============
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.primary;
          }
          return AppColors.slate300;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.primary.withOpacity(0.4);
          }
          return AppColors.slate300.withOpacity(0.4);
        }),
      ),

      // ============= DIVIDER THEME =============
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),

      // ============= SCAFFOLD BACKGROUND =============
      scaffoldBackgroundColor: AppColors.background,
    );
  }

  /// Build text theme using Google Fonts
  static TextTheme _buildTextTheme() {
    final base = GoogleFonts.outfitTextTheme();
    return base.copyWith(
      displayLarge: AppTypography.displayLarge(),
      displayMedium: AppTypography.displayMedium(),
      displaySmall: AppTypography.displaySmall(),
      headlineLarge: AppTypography.headlineLarge(),
      headlineMedium: AppTypography.headlineMedium(),
      headlineSmall: AppTypography.headlineSmall(),
      titleLarge: AppTypography.titleLarge(),
      titleMedium: AppTypography.titleMedium(),
      titleSmall: AppTypography.titleSmall(),
      bodyLarge: AppTypography.bodyLarge(),
      bodyMedium: AppTypography.bodyMedium(),
      bodySmall: AppTypography.bodySmall(),
      labelLarge: AppTypography.labelLarge(),
      labelMedium: AppTypography.labelMedium(),
      labelSmall: AppTypography.labelSmall(),
    );
  }
}
