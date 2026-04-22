import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/printer/printer_models.dart';
import '../../services/printer/printer_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_card.dart';

/// Print preview dialog
class AppPrintPreview extends StatelessWidget {
  final String title;
  final String receiptId;
  final int totalCents;
  final String currency;
  final List<Map<String, dynamic>> items;
  final String? paymentMethod;
  final VoidCallback onPrint;
  final VoidCallback? onCancel;

  const AppPrintPreview({
    Key? key,
    required this.title,
    required this.receiptId,
    required this.totalCents,
    required this.currency,
    required this.items,
    this.paymentMethod,
    required this.onPrint,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              Text(
                'Print Preview',
                style: AppTypography.headlineMedium(),
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),

              // Preview
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTypography.titleLarge(
                        weight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Receipt #$receiptId',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Items preview
                    for (final item in items.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                (item['name'] as String?) ?? 'Item',
                                style: AppTypography.bodySmall(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(item['quantity'] ?? 0)}x',
                              style: AppTypography.bodySmall(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (items.length > 3)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Text(
                          '+${items.length - 3} more items',
                          style: AppTypography.bodySmall(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: AppTypography.titleMedium(
                            weight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$currency ${(totalCents / 100).toStringAsFixed(2)}',
                          style: AppTypography.titleMedium(
                            color: AppColors.primary,
                            weight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel ?? () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print'),
                      onPressed: () {
                        onPrint();
                        Navigator.pop(context);
                      },
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
}

/// Print progress dialog
class AppPrintProgress extends ConsumerWidget {
  final String receiptId;
  final VoidCallback? onDismiss;

  const AppPrintProgress({
    Key? key,
    required this.receiptId,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(printerServiceProvider);
    final job = service.getPrintJobStatus(receiptId);

    if (job == null) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outlined,
                size: 64,
                color: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Print Completed',
                style: AppTypography.titleLarge(),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  onDismiss?.call();
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (job.isFailed)
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              )
            else if (job.isCompleted)
              Icon(
                Icons.check_circle_outlined,
                size: 64,
                color: AppColors.success,
              )
            else
              const SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _getStatusText(job),
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              job.receiptId,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall(color: AppColors.textSecondary),
            ),
            if (job.isFailed && job.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  job.errorMessage!,
                  style: AppTypography.bodySmall(color: AppColors.error),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (!job.isCompleted && !job.isFailed)
              Text(
                'Do not interrupt printing',
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall(color: AppColors.textSecondary),
              )
            else
              FilledButton(
                onPressed: () {
                  onDismiss?.call();
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(PrintJob job) {
    return switch (job.status) {
      PrintJobStatus.pending => 'Queued for printing',
      PrintJobStatus.printing => 'Printing...',
      PrintJobStatus.completed => 'Print completed',
      PrintJobStatus.failed => 'Print failed',
      PrintJobStatus.cancelled => 'Print cancelled',
    };
  }
}

/// Test print dialog
class AppPrinterTestDialog extends ConsumerStatefulWidget {
  final VoidCallback? onSuccess;
  final VoidCallback? onError;

  const AppPrinterTestDialog({
    Key? key,
    this.onSuccess,
    this.onError,
  }) : super(key: key);

  @override
  ConsumerState<AppPrinterTestDialog> createState() => _AppPrinterTestDialogState();
}

class _AppPrinterTestDialogState extends ConsumerState<AppPrinterTestDialog> {
  bool _isPrinting = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
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
              Text(
                'Printer Test',
                style: AppTypography.headlineMedium(),
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 40,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Test Failed',
                        style: AppTypography.titleMedium(color: AppColors.error),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall(color: AppColors.error),
                      ),
                    ],
                  ),
                )
              else if (_isPrinting)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Sending test page...',
                        style: AppTypography.titleMedium(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Make sure printer is ready',
                        style: AppTypography.bodySmall(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Test Completed',
                        style: AppTypography.titleLarge(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Check your printer',
                        style: AppTypography.bodySmall(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),

              if (!_isPrinting && _errorMessage == null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: _testPrint,
                        child: const Text('Print Again'),
                      ),
                    ),
                  ],
                )
              else if (!_isPrinting && _errorMessage != null)
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
                        onPressed: _testPrint,
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                )
              else
                FilledButton(
                  onPressed: null,
                  child: const Text('Printing...'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _testPrint() async {
    setState(() {
      _isPrinting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(printerServiceProvider).printTest();
      setState(() => _isPrinting = false);
      widget.onSuccess?.call();
    } catch (e) {
      setState(() {
        _isPrinting = false;
        _errorMessage = e.toString();
      });
      widget.onError?.call();
    }
  }
}
