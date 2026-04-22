import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Quantity selector control with increment/decrement buttons
class AppQuantitySelector extends StatelessWidget {
  final num quantity;
  final ValueChanged<num> onChanged;
  final num minQuantity;
  final num maxQuantity;
  final bool compact;

  const AppQuantitySelector({
    Key? key,
    required this.quantity,
    required this.onChanged,
    this.minQuantity = 0.001,
    this.maxQuantity = 999999,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact();
    }
    return _buildNormal();
  }

  Widget _buildCompact() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(Icons.remove, () {
            final newQty = quantity - 1;
            if (newQty >= minQuantity) onChanged(newQty);
          }, quantity <= minQuantity),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: SizedBox(
              width: 40,
              child: Text(
                quantity.toString(),
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium(),
              ),
            ),
          ),
          _buildButton(Icons.add, () {
            final newQty = quantity + 1;
            if (newQty <= maxQuantity) onChanged(newQty);
          }, quantity >= maxQuantity),
        ],
      ),
    );
  }

  Widget _buildNormal() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quantity', style: AppTypography.labelMedium()),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildButton(Icons.remove, () {
                  final newQty = quantity - 1;
                  if (newQty >= minQuantity) onChanged(newQty);
                }, quantity <= minQuantity, size: 'large'),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2),
                    textAlign: TextAlign.center,
                    style: AppTypography.displaySmall(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildButton(Icons.add, () {
                  final newQty = quantity + 1;
                  if (newQty <= maxQuantity) onChanged(newQty);
                }, quantity >= maxQuantity, size: 'large'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    IconData icon,
    VoidCallback onPressed,
    bool isDisabled, {
    String size = 'small',
  }) {
    final btnSize = size == 'large' ? AppSpacing.buttonHeightMd : 32.0;
    final iconSize = size == 'large' ? AppSpacing.iconSizeLg : AppSpacing.iconSizeMd;

    return SizedBox(
      height: btnSize,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: isDisabled ? AppColors.disabled : AppColors.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
        onPressed: isDisabled ? null : onPressed,
        child: Icon(icon, size: iconSize),
      ),
    );
  }
}

/// Quick quantity input dialog
class QuantityInputDialog extends StatefulWidget {
  final num initialQuantity;
  final String productName;
  final num minQuantity;
  final num maxQuantity;

  const QuantityInputDialog({
    Key? key,
    required this.initialQuantity,
    required this.productName,
    this.minQuantity = 0.001,
    this.maxQuantity = 999999,
  }) : super(key: key);

  @override
  State<QuantityInputDialog> createState() => _QuantityInputDialogState();
}

class _QuantityInputDialogState extends State<QuantityInputDialog> {
  late num _quantity;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity;
    _controller = TextEditingController(text: _quantity.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Set Quantity', style: AppTypography.headlineMedium()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.productName,
            style: AppTypography.bodyMedium(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quantity',
              hintText: '1.0',
            ),
            onChanged: (value) {
              _quantity = num.tryParse(value) ?? widget.initialQuantity;
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _quantity >= widget.minQuantity && _quantity <= widget.maxQuantity
              ? () => Navigator.pop(context, _quantity)
              : null,
          child: const Text('Set'),
        ),
      ],
    );
  }
}
