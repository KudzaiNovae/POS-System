# 🖨️ Printer Integration - Implementation Examples

Complete integration examples for adding printing to your TillPro screens.

---

## 1. POS Screen Integration

### Add Printer Status to AppBar

```dart
// In pos_screen.dart

import '../../core/widgets/printer/app_printer_selector.dart';
import '../../core/services/printer/printer_provider.dart';

class POSScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sale'),
        actions: [
          // Printer status indicator
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppPrinterStatus(compact: true),
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: _buildPOSContent(),
    );
  }

  Widget _buildPOSContent() {
    // ... existing POS UI ...
  }
}
```

### Enhance Sale Completion Dialog

```dart
// Modified SaleCompletionDialog to include print button

class SaleCompletionDialog extends ConsumerStatefulWidget {
  final String saleId;
  final int totalCents;
  final String currency;
  final Sale saleData;
  final VoidCallback onViewReceipt;
  final VoidCallback onNewSale;

  const SaleCompletionDialog({
    Key? key,
    required this.saleId,
    required this.totalCents,
    required this.currency,
    required this.saleData,
    required this.onViewReceipt,
    required this.onNewSale,
  }) : super(key: key);

  @override
  ConsumerState<SaleCompletionDialog> createState() => 
    _SaleCompletionDialogState();
}

class _SaleCompletionDialogState 
    extends ConsumerState<SaleCompletionDialog> {
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(printerConnectedProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
        borderRadius: AppSpacing.radiusXl,
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
                  Text('Amount', style: AppTypography.labelMedium(
                    color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${widget.currency} ${(widget.totalCents / 100).toStringAsFixed(2)}',
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
                    widget.saleId,
                    style: AppTypography.monospace(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Action buttons
            FilledButton.icon(
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('View Receipt'),
              onPressed: widget.onViewReceipt,
            ),
            const SizedBox(height: AppSpacing.sm),
            
            // Print button (only if printer connected)
            if (isConnected)
              FilledButton.icon(
                icon: _isPrinting 
                  ? const SizedBox(
                      width: 20, 
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.print_outlined),
                label: Text(_isPrinting ? 'Printing...' : 'Print Receipt'),
                onPressed: _isPrinting ? null : () => _printReceipt(),
              )
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.print_disabled_outlined),
                label: const Text('Connect Printer'),
                onPressed: () => _showPrinterSelector(),
              ),
            const SizedBox(height: AppSpacing.sm),
            
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New Sale'),
              onPressed: widget.onNewSale,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printReceipt() async {
    setState(() => _isPrinting = true);

    try {
      final formatter = ReceiptFormatter();
      final escposData = formatter.formatSaleReceipt(
        shopName: 'Your Shop Name',
        saleId: widget.saleId,
        items: widget.saleData.items.map((item) => {
          'name': item.productName,
          'quantity': item.quantity,
          'unitPrice': item.unitPrice,
          'lineTotal': item.lineTotalCents,
        }).toList(),
        subtotalCents: widget.saleData.subtotalCents,
        vatCents: widget.saleData.vatCents,
        totalCents: widget.totalCents,
        paymentMethod: widget.saleData.paymentMethod,
        currency: widget.currency,
        printQrCode: true,
      );

      final jobId = await ref.read(printerServiceProvider)
          .queuePrintJob(
            receiptId: widget.saleId,
            escposData: escposData,
          );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AppPrintProgress(receiptId: jobId),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  void _showPrinterSelector() {
    showDialog(
      context: context,
      builder: (_) => AppPrinterSelector(
        onConnected: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Printer connected'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }
}
```

---

## 2. Receipt Screen Integration

### Enhanced Receipt Screen with Print

```dart
// lib/features/receipt/receipt_screen.dart

import '../../core/widgets/printer/app_print_dialog.dart';
import '../../core/services/printer/escpos_builder.dart';
import '../../core/services/printer/printer_provider.dart';

class ReceiptScreen extends ConsumerWidget {
  final String saleId;

  const ReceiptScreen({
    Key? key,
    required this.saleId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sale = _loadSaleData(saleId);

    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt #$saleId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _shareReceipt(context, sale),
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () => _printReceipt(context, ref, sale),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_outlined),
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _buildReceiptContent(sale),
      ),
    );
  }

  void _printReceipt(
    BuildContext context,
    WidgetRef ref,
    Sale sale,
  ) {
    final isConnected = ref.read(printerConnectedProvider);

    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect a printer first'),
          backgroundColor: AppColors.warning,
        ),
      );
      context.push('/settings');
      return;
    }

    // Show preview
    showDialog(
      context: context,
      builder: (_) => AppPrintPreview(
        title: 'My Shop',
        receiptId: sale.id,
        totalCents: sale.totalCents,
        currency: 'KES',
        items: sale.items.map((item) => {
          'name': item.productName,
          'quantity': item.quantity,
          'unitPrice': item.unitPrice,
          'lineTotal': item.lineTotalCents,
        }).toList(),
        onPrint: () => _sendToPrinter(context, ref, sale),
      ),
    );
  }

  Future<void> _sendToPrinter(
    BuildContext context,
    WidgetRef ref,
    Sale sale,
  ) async {
    try {
      final formatter = ReceiptFormatter();
      final escposData = formatter.formatSaleReceipt(
        shopName: 'My Shop',
        saleId: sale.id,
        items: sale.items.map((item) => {
          'name': item.productName,
          'quantity': item.quantity,
          'unitPrice': item.unitPrice,
          'lineTotal': item.lineTotalCents,
        }).toList(),
        subtotalCents: sale.subtotalCents,
        vatCents: sale.vatCents,
        totalCents: sale.totalCents,
        paymentMethod: sale.paymentMethod,
        shopAddress: '123 Main St',
        shopPhone: '+256-123-4567',
      );

      final jobId = await ref.read(printerServiceProvider)
          .queuePrintJob(
            receiptId: sale.id,
            escposData: escposData,
          );

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AppPrintProgress(receiptId: jobId),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _shareReceipt(BuildContext context, Sale sale) {
    // Share receipt PDF or text
  }

  void _showMenu(BuildContext context) {
    // Show more options
  }

  Widget _buildReceiptContent(Sale sale) {
    // Your existing receipt UI
    return const SizedBox();
  }

  Sale _loadSaleData(String saleId) {
    // Load sale from database
    return Sale.empty();
  }
}
```

---

## 3. Main App Integration

### Initialize Printer Service

```dart
// In main.dart or app initialization

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local database
  await initializeHiveBoxes();
  
  // Initialize printer service
  final printerService = PrinterService();
  await printerService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.lightTheme(),
      ),
    );
  }
}
```

### Add Settings Route

```dart
// In your router/navigation configuration

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const POSScreen(),
    ),
    GoRoute(
      path: '/receipt/:saleId',
      builder: (context, state) => ReceiptScreen(
        saleId: state.pathParameters['saleId']!,
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    // ... other routes
  ],
);
```

---

## 4. Auto-Print Configuration

### Enable Auto-Print

```dart
// In your sale completion logic

Future<void> completeSale(Sale sale, WidgetRef ref) async {
  // Enqueue sale for sync
  await ref.read(saleServiceProvider).enqueueSale(sale);

  // Check auto-print setting
  final prefs = await SharedPreferences.getInstance();
  final autoPrint = prefs.getBool('autoPrint') ?? false;

  if (autoPrint) {
    final formatter = ReceiptFormatter();
    final escposData = formatter.formatSaleReceipt(
      shopName: 'My Shop',
      saleId: sale.id,
      items: sale.items,
      subtotalCents: sale.subtotalCents,
      vatCents: sale.vatCents,
      totalCents: sale.totalCents,
      paymentMethod: sale.paymentMethod,
    );

    // Queue print job
    await ref.read(printerServiceProvider).queuePrintJob(
      receiptId: sale.id,
      escposData: escposData,
    );
  }

  // Show completion dialog
  if (context.mounted) {
    await showDialog(
      context: context,
      builder: (_) => SaleCompletionDialog(
        saleId: sale.id,
        totalCents: sale.totalCents,
        saleData: sale,
        onViewReceipt: () => context.push('/receipt/${sale.id}'),
        onNewSale: () => _clearCart(),
      ),
    );
  }
}
```

---

## 5. Error Handling

### Complete Error Handling

```dart
Future<void> handlePrintError(
  BuildContext context,
  dynamic error,
  WidgetRef ref,
) async {
  String message;
  String action = 'Retry';

  if (error is PrinterException) {
    switch (error.code) {
      case 'NO_PRINTER':
        message = 'No printer connected. Please connect a printer.';
        action = 'Settings';
        break;
      case 'CONNECTION_FAILED':
        message = 'Failed to connect to printer. Check device power.';
        action = 'Retry';
        break;
      case 'PRINT_FAILED':
        message = 'Print operation failed. Check printer status.';
        action = 'Retry';
        break;
      default:
        message = 'Printer error: ${error.message}';
        action = 'Close';
    }
  } else {
    message = 'Unexpected error: $error';
    action = 'Close';
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        action: SnackBarAction(
          label: action,
          onPressed: () {
            if (action == 'Settings') {
              context.push('/settings');
            } else if (action == 'Retry') {
              // Retry logic
            }
          },
        ),
      ),
    );
  }
}
```

---

## 6. Testing Checklist

### Unit Tests
```dart
test('ESCPOSBuilder generates valid data', () {
  final builder = ESCPOSBuilder();
  builder.initialize();
  builder.text('Hello');
  final data = builder.build();
  
  expect(data, isNotEmpty);
  expect(data[0], equals(0x1B)); // ESC character
});

test('ReceiptFormatter creates valid receipt', () {
  final formatter = ReceiptFormatter();
  final data = formatter.formatSaleReceipt(
    shopName: 'Test Shop',
    saleId: 'TEST_001',
    items: [],
    subtotalCents: 1000,
    vatCents: 100,
    totalCents: 1100,
  );
  
  expect(data, isNotEmpty);
});
```

### Widget Tests
```dart
testWidgets('AppPrinterStatus shows connection status', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppPrinterStatus(compact: false),
      ),
    ),
  );

  expect(find.byIcon(Icons.print_disabled_outlined), findsOneWidget);
});
```

### Integration Tests
```dart
testWidgets('Complete print flow', (tester) async {
  // Navigate to receipt
  await tester.tap(find.byIcon(Icons.print_outlined));
  await tester.pumpAndSettle();

  // Find print preview dialog
  expect(find.byType(AppPrintPreview), findsOneWidget);

  // Tap print button
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();

  // Should show progress dialog
  expect(find.byType(AppPrintProgress), findsOneWidget);
});
```

---

## 7. Settings Persistence

### Save Print Settings

```dart
// In settings_screen.dart

void _saveSettings() async {
  final prefs = await SharedPreferences.getInstance();
  
  // Save print settings
  await prefs.setBool('autoPrint', _autoPrint);
  await prefs.setBool('showPrintDialog', _showPrintDialog);
  await prefs.setInt('paperWidth', _paperWidth);
  await prefs.setInt('fontSize', _fontSize);
  await prefs.setBool('printBarcode', _printBarcode);
  await prefs.setBool('printQrCode', _printQrCode);
  
  // Save shop info
  await prefs.setString('shopName', _shopNameController.text);
  await prefs.setString('shopAddress', _shopAddressController.text);
  await prefs.setString('shopPhone', _shopPhoneController.text);
  
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Settings saved'),
      backgroundColor: AppColors.success,
    ),
  );
}
```

### Load Print Settings

```dart
Future<PrintSettings> loadPrintSettings() async {
  final prefs = await SharedPreferences.getInstance();
  
  return PrintSettings(
    autoPrint: prefs.getBool('autoPrint') ?? false,
    showPrintDialog: prefs.getBool('showPrintDialog') ?? true,
    paperWidth: prefs.getInt('paperWidth') ?? 80,
    fontSize: prefs.getInt('fontSize') ?? 1,
    printBarcode: prefs.getBool('printBarcode') ?? false,
    printQrCode: prefs.getBool('printQrCode') ?? true,
    shopName: prefs.getString('shopName'),
    shopAddress: prefs.getString('shopAddress'),
    shopPhone: prefs.getString('shopPhone'),
  );
}
```

---

**Version**: 1.0.0  
**Last Updated**: 2026-04-21
