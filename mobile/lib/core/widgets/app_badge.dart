import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Status badge/tag component
class AppBadge extends StatelessWidget {
  final String label;
  final BadgeType type;
  final IconData? icon;
  final VoidCallback? onClose;

  const AppBadge({
    Key? key,
    required this.label,
    required this.type,
    this.icon,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = _getColors(type);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors['bg'] as Color,
        border: Border.all(color: colors['border'] as Color),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSpacing.iconSizeSm, color: colors['color'] as Color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: AppTypography.badge(color: colors['color'] as Color)),
          if (onClose != null) ...[
            const SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close, size: AppSpacing.iconSizeSm, color: colors['color'] as Color),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _getColors(BadgeType type) {
    return switch (type) {
      BadgeType.success => {
        'bg': AppColors.successBg,
        'border': AppColors.success.withOpacity(0.3),
        'color': AppColors.success,
      },
      BadgeType.warning => {
        'bg': AppColors.warningBg,
        'border': AppColors.warning.withOpacity(0.3),
        'color': AppColors.warning,
      },
      BadgeType.error => {
        'bg': AppColors.errorBg,
        'border': AppColors.error.withOpacity(0.3),
        'color': AppColors.error,
      },
      BadgeType.info => {
        'bg': AppColors.infoBg,
        'border': AppColors.info.withOpacity(0.3),
        'color': AppColors.info,
      },
      BadgeType.primary => {
        'bg': AppColors.primaryVeryLight,
        'border': AppColors.primary.withOpacity(0.3),
        'color': AppColors.primary,
      },
      BadgeType.neutral => {
        'bg': AppColors.slate100,
        'border': AppColors.slate200,
        'color': AppColors.slate600,
      },
    };
  }
}

enum BadgeType { success, warning, error, info, primary, neutral }

/// Stock status badge with color coding
class StockBadge extends StatelessWidget {
  final num qty;
  final num reorderLevel;
  final String? unit;

  const StockBadge({
    Key? key,
    required this.qty,
    required this.reorderLevel,
    this.unit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = _getStatus();
    final type = _getType();
    final icon = _getIcon();

    return AppBadge(
      label: '$qty${unit != null ? ' $unit' : ''}',
      type: type,
      icon: icon,
    );
  }

  String _getStatus() {
    if (qty <= 0) return 'Out';
    if (qty <= reorderLevel) return 'Low';
    return 'OK';
  }

  BadgeType _getType() {
    if (qty <= 0) return BadgeType.error;
    if (qty <= reorderLevel) return BadgeType.warning;
    return BadgeType.success;
  }

  IconData _getIcon() {
    if (qty <= 0) return Icons.block_outlined;
    if (qty <= reorderLevel) return Icons.warning_outlined;
    return Icons.check_circle_outlined;
  }
}

/// Payment method badge
class PaymentBadge extends StatelessWidget {
  final String paymentMethod;

  const PaymentBadge({
    Key? key,
    required this.paymentMethod,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final icon = _getIcon();
    final label = _getLabel();
    final type = BadgeType.primary;

    return AppBadge(
      label: label,
      type: type,
      icon: icon,
    );
  }

  String _getLabel() {
    return switch (paymentMethod.toUpperCase()) {
      'CASH' => 'Cash',
      'MPESA' => 'M-Pesa',
      'MOMO' => 'MoMo',
      'CARD' => 'Card',
      'CREDIT' => 'Credit',
      _ => paymentMethod,
    };
  }

  IconData _getIcon() {
    return switch (paymentMethod.toUpperCase()) {
      'CASH' => Icons.payments_outlined,
      'MPESA' => Icons.phone_android_outlined,
      'MOMO' => Icons.phone_android_outlined,
      'CARD' => Icons.credit_card_outlined,
      'CREDIT' => Icons.receipt_long_outlined,
      _ => Icons.payment_outlined,
    };
  }
}

/// Fiscal status badge
class FiscalStatusBadge extends StatelessWidget {
  final String? fiscalStatus;

  const FiscalStatusBadge({
    Key? key,
    this.fiscalStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (fiscalStatus == null) return const SizedBox.shrink();

    final type = _getType();
    final icon = _getIcon();

    return AppBadge(
      label: _getLabel(),
      type: type,
      icon: icon,
    );
  }

  String _getLabel() {
    return switch (fiscalStatus?.toUpperCase()) {
      'PENDING' => 'Pending',
      'SUBMITTED' => 'Submitted',
      'FAILED' => 'Failed',
      _ => fiscalStatus ?? '',
    };
  }

  BadgeType _getType() {
    return switch (fiscalStatus?.toUpperCase()) {
      'PENDING' => BadgeType.info,
      'SUBMITTED' => BadgeType.success,
      'FAILED' => BadgeType.error,
      _ => BadgeType.neutral,
    };
  }

  IconData _getIcon() {
    return switch (fiscalStatus?.toUpperCase()) {
      'PENDING' => Icons.schedule_outlined,
      'SUBMITTED' => Icons.check_circle_outlined,
      'FAILED' => Icons.error_outlined,
      _ => Icons.info_outlined,
    };
  }
}
