import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// Enhanced checkout dialog with payment method and customer info
class AppCheckoutDialog extends StatefulWidget {
  final int totalCents;
  final String currency;
  final String? defaultPaymentMethod;
  final VoidCallback? onCustomerRequired;

  const AppCheckoutDialog({
    Key? key,
    required this.totalCents,
    this.currency = 'KES',
    this.defaultPaymentMethod,
    this.onCustomerRequired,
  }) : super(key: key);

  @override
  State<AppCheckoutDialog> createState() => _AppCheckoutDialogState();
}

class _AppCheckoutDialogState extends State<AppCheckoutDialog> {
  late String _selectedPayment;
  late TextEditingController _refController;
  late TextEditingController _customerController;
  bool _collectCustomer = false;

  @override
  void initState() {
    super.initState();
    _selectedPayment = widget.defaultPaymentMethod ?? 'CASH';
    _refController = TextEditingController();
    _customerController = TextEditingController();
  }

  @override
  void dispose() {
    _refController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalDisplay = (widget.totalCents / 100).toStringAsFixed(2);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
        borderRadius: AppSpacing.radiusXl,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Complete Sale', style: AppTypography.headlineMedium()),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: AppSpacing.md),

              // Amount
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.primaryVeryLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  children: [
                    Text('Total Amount', style: AppTypography.labelMedium()),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${widget.currency} $totalDisplay',
                      style: AppTypography.displayMedium(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Payment Method
              Text('Payment Method', style: AppTypography.titleMedium()),
              const SizedBox(height: AppSpacing.md),
              _buildPaymentMethods(),
              const SizedBox(height: AppSpacing.lg),

              // Reference (conditional)
              if (_selectedPayment != 'CASH' && _selectedPayment != 'CREDIT') ...[
                Text('Payment Reference (Optional)', style: AppTypography.titleMedium()),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _refController,
                  decoration: const InputDecoration(
                    labelText: 'Ref/Transaction ID',
                    hintText: 'e.g., QJX7A1BC',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Customer collection
              Row(
                children: [
                  Checkbox(
                    value: _collectCustomer,
                    onChanged: (v) => setState(() => _collectCustomer = v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'Collect customer details',
                      style: AppTypography.bodyMedium(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Customer info (conditional)
              if (_collectCustomer) ...[
                TextField(
                  controller: _customerController,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    hintText: 'e.g., John Doe',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        CheckoutResult(
                          paymentMethod: _selectedPayment,
                          paymentRef: _refController.text.isEmpty ? null : _refController.text,
                          customerName: _customerController.text.isEmpty ? null : _customerController.text,
                        ),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethods() {
    final methods = [
      ('CASH', 'Cash', Icons.payments_outlined),
      ('MPESA', 'M-Pesa', Icons.phone_android_outlined),
      ('MOMO', 'MoMo', Icons.phone_android_outlined),
      ('CARD', 'Card', Icons.credit_card_outlined),
      ('CREDIT', 'On Credit', Icons.receipt_long_outlined),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      children: methods.map((m) {
        final (code, label, icon) = m;
        final isSelected = _selectedPayment == code;

        return GestureDetector(
          onTap: () => setState(() => _selectedPayment = code),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryVeryLight : AppColors.surfaceAlt,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: AppSpacing.iconSizeLg,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMedium(
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    weight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Checkout result model
class CheckoutResult {
  final String paymentMethod;
  final String? paymentRef;
  final String? customerName;

  CheckoutResult({
    required this.paymentMethod,
    this.paymentRef,
    this.customerName,
  });
}

/// Sale completion confirmation dialog
class SaleCompletionDialog extends StatelessWidget {
  final String saleId;
  final int totalCents;
  final String currency;
  final VoidCallback onViewReceipt;
  final VoidCallback onNewSale;

  const SaleCompletionDialog({
    Key? key,
    required this.saleId,
    required this.totalCents,
    this.currency = 'KES',
    required this.onViewReceipt,
    required this.onNewSale,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalDisplay = (totalCents / 100).toStringAsFixed(2);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
        borderRadius: AppSpacing.radiusXl,
        backgroundColor: AppColors.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success icon
            Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(top: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outlined,
                size: 48,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              'Sale Completed!',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLarge(),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Amount
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                children: [
                  Text('Amount', style: AppTypography.labelMedium(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$currency $totalDisplay',
                    style: AppTypography.currency(color: AppColors.success),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Sale ID
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sale ID', style: AppTypography.labelSmall()),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    saleId,
                    style: AppTypography.monospace(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Actions
            FilledButton.icon(
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('View Receipt'),
              onPressed: onViewReceipt,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New Sale'),
              onPressed: onNewSale,
            ),
          ],
        ),
      ),
    );
  }
}
