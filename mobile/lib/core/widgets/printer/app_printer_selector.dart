import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/printer/printer_models.dart';
import '../../services/printer/printer_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_card.dart';

/// Printer selection and discovery dialog
class AppPrinterSelector extends ConsumerStatefulWidget {
  final VoidCallback? onConnected;
  final VoidCallback? onCancelled;

  const AppPrinterSelector({
    Key? key,
    this.onConnected,
    this.onCancelled,
  }) : super(key: key);

  @override
  ConsumerState<AppPrinterSelector> createState() => _AppPrinterSelectorState();
}

class _AppPrinterSelectorState extends ConsumerState<AppPrinterSelector> {
  PrinterDevice? _selectedDevice;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(printerServiceProvider).startScanning();
    });
  }

  @override
  void dispose() {
    ref.read(printerServiceProvider).stopScanning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isScanning = ref.watch(printerScanningProvider);
    final availablePrinters = ref.watch(availablePrintersProvider);

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
                  Text(
                    'Select Printer',
                    style: AppTypography.headlineMedium(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      widget.onCancelled?.call();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: AppSpacing.md),

              // Scanning indicator
              if (isScanning)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Scanning for devices...',
                      style: AppTypography.bodyMedium(color: AppColors.textSecondary),
                    ),
                  ],
                )
              else if (availablePrinters.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Column(
                    children: [
                      Icon(
                        Icons.print_disabled_outlined,
                        size: 48,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No printers found',
                        style: AppTypography.titleMedium(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Make sure your printer is turned on and paired',
                        style: AppTypography.bodySmall(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                _buildPrinterList(availablePrinters),

              const SizedBox(height: AppSpacing.lg),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isScanning
                          ? null
                          : () {
                        widget.onCancelled?.call();
                        Navigator.pop(context);
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: (_selectedDevice == null || _isConnecting)
                          ? null
                          : _connectSelected,
                      child: _isConnecting
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                          : const Text('Connect'),
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

  Widget _buildPrinterList(List<PrinterDevice> devices) {
    return Column(
      children: devices.asMap().entries.map((entry) {
        final device = entry.value;
        final index = entry.key;
        final isSelected = _selectedDevice?.id == device.id;

        return GestureDetector(
          onTap: () {
            setState(() => _selectedDevice = device);
          },
          child: Container(
            margin: EdgeInsets.only(bottom: index < devices.length - 1 ? AppSpacing.sm : 0),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryVeryLight : AppColors.surfaceAlt,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  _getDeviceIcon(device.type),
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: AppTypography.titleSmall(
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          weight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        device.connectionType.name.toUpperCase(),
                        style: AppTypography.labelSmall(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _connectSelected() async {
    if (_selectedDevice == null) return;

    setState(() => _isConnecting = true);

    try {
      await ref.read(printerServiceProvider).connectPrinter(_selectedDevice!);
      widget.onConnected?.call();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  IconData _getDeviceIcon(PrinterType type) {
    return switch (type) {
      PrinterType.thermal => Icons.receipt_long_outlined,
      PrinterType.inkjet => Icons.print_outlined,
      PrinterType.laser => Icons.print_outlined,
      PrinterType.unknown => Icons.device_unknown_outlined,
    };
  }
}

/// Printer status widget
class AppPrinterStatus extends ConsumerWidget {
  final bool compact;

  const AppPrinterStatus({
    Key? key,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(printerConnectedProvider);
    final selectedPrinter = ref.watch(selectedPrinterProvider);

    if (!isConnected || selectedPrinter == null) {
      return compact
          ? Tooltip(
        message: 'No printer connected',
        child: Icon(
          Icons.print_disabled_outlined,
          size: 20,
          color: AppColors.textTertiary,
        ),
      )
          : GestureDetector(
        onTap: () => _showPrinterSelector(context),
        child: AppCard(
          child: Row(
            children: [
              Icon(
                Icons.print_disabled_outlined,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Printer',
                      style: AppTypography.labelMedium(),
                    ),
                    Text(
                      'Tap to connect',
                      style: AppTypography.labelSmall(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      );
    }

    return compact
        ? Tooltip(
      message: '${selectedPrinter.name} (${selectedPrinter.connectionType.name})',
      child: Icon(
        Icons.print_outlined,
        size: 20,
        color: AppColors.success,
      ),
    )
        : AppCard(
      child: Row(
        children: [
          Icon(
            Icons.print_outlined,
            color: AppColors.success,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedPrinter.name,
                  style: AppTypography.labelMedium(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  selectedPrinter.connectionType.name.toUpperCase(),
                  style: AppTypography.labelSmall(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showPrinterSelector(context),
            child: const Icon(
              Icons.edit_outlined,
              size: 16,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showPrinterSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AppPrinterSelector(
        onConnected: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printer connected')),
        ),
      ),
    );
  }
}
