import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../format/money.dart';
import 'app_card.dart';

/// Cart line item with quantity and delete controls
class CartLineItem extends StatelessWidget {
  final String productName;
  final num quantity;
  final String unit;
  final int unitPrice;
  final int lineTotal;
  final ValueChanged<num> onQuantityChanged;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  const CartLineItem({
    Key? key,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.lineTotal,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: AppTypography.titleMedium(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      '${Money.cents(unitPrice)} × $quantity $unit',
                      style: AppTypography.bodySmall(color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    GestureDetector(
                      onTap: onEdit,
                      child: Text(
                        'Edit',
                        style: AppTypography.labelSmall(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Total and delete
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Money.cents(lineTotal),
                style: AppTypography.titleLarge(
                  color: AppColors.primary,
                  weight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.delete_outline,
                  size: AppSpacing.iconSizeMd,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cart summary box showing totals and checkout button
class CartSummary extends StatelessWidget {
  final int subtotalCents;
  final int vatCents;
  final int totalCents;
  final int itemCount;
  final bool isLoading;
  final VoidCallback onCheckout;
  final String? primaryButtonLabel;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryAction;

  const CartSummary({
    Key? key,
    required this.subtotalCents,
    required this.vatCents,
    required this.totalCents,
    required this.itemCount,
    required this.onCheckout,
    this.isLoading = false,
    this.primaryButtonLabel = 'Checkout',
    this.secondaryButtonLabel,
    this.onSecondaryAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Heading
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Cart',
                style: AppTypography.titleLarge(weight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryVeryLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
                ),
                child: Text(
                  '$itemCount item${itemCount != 1 ? 's' : ''}',
                  style: AppTypography.labelSmall(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),

          // Breakdown
          _buildRow('Subtotal', Money.cents(subtotalCents), AppColors.textSecondary),
          const SizedBox(height: AppSpacing.sm),
          _buildRow('VAT', Money.cents(vatCents), AppColors.textSecondary),
          const Divider(height: AppSpacing.lg),

          // Total
          _buildRow(
            'Total',
            Money.cents(totalCents),
            AppColors.primary,
            isBold: true,
            fontSize: 20,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Buttons
          FilledButton(
            onPressed: isLoading || itemCount == 0 ? null : onCheckout,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(primaryButtonLabel ?? 'Checkout'),
          ),
          if (secondaryButtonLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: onSecondaryAction,
              child: Text(secondaryButtonLabel!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
    double fontSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold
              ? AppTypography.titleLarge(color: color, weight: FontWeight.bold)
              : AppTypography.bodyMedium(color: color),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Empty cart message
class EmptyCart extends StatelessWidget {
  final VoidCallback onAddProducts;

  const EmptyCart({
    Key? key,
    required this.onAddProducts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Your cart is empty',
            textAlign: TextAlign.center,
            style: AppTypography.titleLarge(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add products to get started',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onAddProducts,
            icon: const Icon(Icons.add),
            label: const Text('Add Products'),
          ),
        ],
      ),
    );
  }
}
