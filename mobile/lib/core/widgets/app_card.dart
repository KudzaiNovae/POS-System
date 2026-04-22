import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Reusable card component with consistent styling
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool isHovering;
  final List<BoxShadow>? shadows;

  const AppCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.border,
    this.borderWidth = 1,
    this.borderRadius = AppSpacing.radiusLg,
    this.onTap,
    this.isHovering = false,
    this.shadows,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? (isHovering ? _defaultHoverShadow : _defaultShadow),
      ),
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }

  static const List<BoxShadow> _defaultShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: AppSpacing.shadowBlurSm,
      offset: Offset(0, AppSpacing.shadowOffsetSm),
    ),
  ];

  static const List<BoxShadow> _defaultHoverShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: AppSpacing.shadowBlurMd,
      offset: Offset(0, AppSpacing.shadowOffsetMd),
    ),
  ];
}

/// Card with a header and optional action
class AppCardWithHeader extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  final VoidCallback? onTap;

  const AppCardWithHeader({
    Key? key,
    required this.title,
    required this.child,
    this.action,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleLarge),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Highlighted/alert card with color background
class AppAlertCard extends StatelessWidget {
  final String? title;
  final String message;
  final AlertType type;
  final IconData? icon;
  final VoidCallback? onDismiss;

  const AppAlertCard({
    Key? key,
    this.title,
    required this.message,
    required this.type,
    this.icon,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = _getColors(type);

    return AppCard(
      backgroundColor: colors['bg'] as Color,
      borderColor: colors['border'] as Color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? _getIcon(type),
            color: colors['color'] as Color,
            size: AppSpacing.iconSizeLg,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!, style: TextStyle(color: colors['color'] as Color, fontWeight: FontWeight.w600)),
                Text(message, style: TextStyle(color: colors['color'] as Color)),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close, color: colors['color'] as Color),
              onPressed: onDismiss,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  IconData _getIcon(AlertType type) {
    return switch (type) {
      AlertType.success => Icons.check_circle_outlined,
      AlertType.warning => Icons.warning_outlined,
      AlertType.error => Icons.error_outlined,
      AlertType.info => Icons.info_outlined,
    };
  }

  Map<String, dynamic> _getColors(AlertType type) {
    return switch (type) {
      AlertType.success => {
        'bg': AppColors.successBg,
        'border': AppColors.success.withOpacity(0.2),
        'color': AppColors.success,
      },
      AlertType.warning => {
        'bg': AppColors.warningBg,
        'border': AppColors.warning.withOpacity(0.2),
        'color': AppColors.warning,
      },
      AlertType.error => {
        'bg': AppColors.errorBg,
        'border': AppColors.error.withOpacity(0.2),
        'color': AppColors.error,
      },
      AlertType.info => {
        'bg': AppColors.infoBg,
        'border': AppColors.info.withOpacity(0.2),
        'color': AppColors.info,
      },
    };
  }
}

enum AlertType { success, warning, error, info }
