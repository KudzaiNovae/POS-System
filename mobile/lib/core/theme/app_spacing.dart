import 'package:flutter/material.dart';

/// Centralized spacing system for TillPro app
/// Following an 8pt grid system for consistency
class AppSpacing {
  AppSpacing._(); // Private constructor

  // ============= BASE SPACING UNITS =============
  static const double xxs = 2.0;  // Extra extra small
  static const double xs = 4.0;   // Extra small
  static const double sm = 8.0;   // Small
  static const double md = 12.0;  // Medium
  static const double lg = 16.0;  // Large
  static const double xl = 24.0;  // Extra large
  static const double xxl = 32.0; // Extra extra large
  static const double xxxl = 48.0; // Triple extra large

  // ============= COMMON PADDING COMBINATIONS =============
  // Edge insets for common layout patterns
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets paddingHorizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHorizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingHorizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets paddingVerticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVerticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVerticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets paddingVerticalXl = EdgeInsets.symmetric(vertical: xl);

  // Page margins
  static const EdgeInsets pageMarginHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets pageMarginVertical = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets pageMargin = EdgeInsets.all(lg);

  // ============= GAP WIDTHS =============
  static const SizedBox gapXxs = SizedBox(width: xxs, height: xxs);
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);

  // Horizontal gaps
  static const SizedBox gapWXs = SizedBox(width: xs);
  static const SizedBox gapWSm = SizedBox(width: sm);
  static const SizedBox gapWMd = SizedBox(width: md);
  static const SizedBox gapWLg = SizedBox(width: lg);
  static const SizedBox gapWXl = SizedBox(width: xl);

  // Vertical gaps
  static const SizedBox gapHXs = SizedBox(height: xs);
  static const SizedBox gapHSm = SizedBox(height: sm);
  static const SizedBox gapHMd = SizedBox(height: md);
  static const SizedBox gapHLg = SizedBox(height: lg);
  static const SizedBox gapHXl = SizedBox(height: xl);
  static const SizedBox gapHXxl = SizedBox(height: xxl);

  // ============= BORDER RADIUS =============
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusRound = 999.0; // Very large for circles

  // BorderRadius objects
  static BorderRadius radiusSm_br = BorderRadius.circular(radiusSm);
  static BorderRadius radiusMd_br = BorderRadius.circular(radiusMd);
  static BorderRadius radiusLg_br = BorderRadius.circular(radiusLg);
  static BorderRadius radiusXl_br = BorderRadius.circular(radiusXl);
  static BorderRadius radiusRound_br = BorderRadius.circular(radiusRound);

  // ============= COMMON DIMENSIONS =============
  static const double buttonHeightSm = 36.0;
  static const double buttonHeightMd = 44.0;
  static const double buttonHeightLg = 52.0;

  static const double iconSizeSm = 16.0;
  static const double iconSizeMd = 20.0;
  static const double iconSizeLg = 24.0;
  static const double iconSizeXl = 32.0;

  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 80.0;

  // ============= ELEVATION / SHADOWS =============
  static const double shadowBlurSm = 4.0;
  static const double shadowBlurMd = 8.0;
  static const double shadowBlurLg = 12.0;
  static const double shadowBlurXl = 16.0;
  static const double shadowBlurXxl = 24.0;

  static const double shadowOffsetSm = 2.0;
  static const double shadowOffsetMd = 4.0;
  static const double shadowOffsetLg = 6.0;
}

// Helper extension for quick access
extension SpacingExtension on num {
  SizedBox get verticalSizedBox => SizedBox(height: toDouble());
  SizedBox get horizontalSizedBox => SizedBox(width: toDouble());
}
