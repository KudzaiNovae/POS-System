import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/local_db.dart';
import '../../core/format/money.dart';
import '../../core/sync/sync_service.dart';
import '../../core/services/printer/printer_provider.dart';
import '../../core/services/printer/escpos_builder.dart';
import '../../core/widgets/printer/app_printer_selector.dart';
import '../../core/widgets/printer/app_print_dialog.dart';
import '../../models/product.dart';
import 'cart_controller.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});
  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String _filter = '';

  List<Product> get _products {
    final all = LocalDb.allProducts();
    if (_filter.isEmpty) return all;
    final f = _filter.toLowerCase();
    return all.where((p) =>
        p.name.toLowerCase().contains(f) ||
        (p.sku?.toLowerCase().contains(f) ?? false) ||
        (p.barcode?.contains(_filter) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final isConnected = ref.watch(printerConnectedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          // Printer status indicator
          Tooltip(
            message: isConnected ? 'Printer connected' : 'No printer',
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                isConnected ? Icons.print_outlined : Icons.print_disabled_outlined,
                color: isConnected ? Colors.green : Colors.grey,
                size: 20,
              ),
            ),
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Row(
        children: [
          // ---------- LEFT: product grid ----------
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                      hintText: 'Search product, SKU, barcode...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    onChanged: (v) => setState(() => _filter = v),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (ctx, i) {
                      final p = _products[i];
                      return _ProductCard(
                        product: p,
                        onTap: () => ref.read(cartControllerProvider.notifier).add(p),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // ---------- RIGHT: cart ----------
          Container(
            width: 380,
            margin: const EdgeInsets.only(top: 8, right: 16, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(-4, 0),
                )
              ],
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined, color: Color(0xFF4F46E5)),
                      SizedBox(width: 8),
                      Text('Current Sale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Expanded(
                  child: cart.lines.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('No items', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: cart.lines.length,
                          separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16, height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (ctx, i) {
                            final l = cart.lines[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              title: Text(l.product.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text('${l.qty} × ${Money.cents(l.product.priceCents)}', style: const TextStyle(color: Color(0xFF64748B))),
                              trailing: Text(Money.cents(l.lineTotalCents), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                              onLongPress: () => ref.read(cartControllerProvider.notifier).remove(l.product.id),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 18, color: Color(0xFF475569))),
                          Text(Money.cents(cart.totalCents), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981), // Emerald
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.phone_android),
                        label: const Text('Pay with EcoCash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        onPressed: cart.lines.isEmpty ? null : () => _checkout('ECOCASH'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.payments_outlined, color: Color(0xFF4F46E5)),
                        label: const Text('Pay with Cash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
                        onPressed: cart.lines.isEmpty ? null : () => _checkout('CASH'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.more_horiz),
                        label: const Text('Other methods'),
                        onPressed: cart.lines.isEmpty ? null : () => _pickOtherMethod(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkout(String method) async {
    final cartState = ref.read(cartControllerProvider);
    if (cartState.lines.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ReceiptPreviewDialog(cartState: cartState, method: method),
    );

    if (confirm == true) {
      await _completeCheckout(method);
    }
  }

  Future<void> _completeCheckout(String method) async {
    final cartCtrl = ref.read(cartControllerProvider.notifier);
    final sale = cartCtrl.buildSale(method);

    for (final line in ref.read(cartControllerProvider).lines) {
      final p = LocalDb.findProduct(line.product.id);
      if (p != null) {
        p.stockQty = p.stockQty - line.qty;
        p.dirty = true;
        await LocalDb.putProduct(p);
      }
    }

    await ref.read(syncServiceProvider).enqueueSale(sale);

    // Auto-print if printer connected and enabled
    final isConnected = ref.read(printerConnectedProvider);
    if (isConnected) {
      await _queuePrintJob(sale);
    }

    cartCtrl.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text('Sale saved · ${Money.cents(sale.totalCents)}')),
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            context.push('/receipt/${sale.id}');
          },
          child: const Text('VIEW RECEIPT',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ]),
      backgroundColor: const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 4),
    ));
    setState(() {});
  }

  Future<void> _queuePrintJob(dynamic sale) async {
    try {
      final formatter = ReceiptFormatter();
      final items = (sale.items as List?)?.map((item) => {
        'name': item.nameSnapshot,
        'quantity': item.qty,
        'unitPrice': item.unitPriceCents,
        'lineTotal': item.lineTotalCents,
      }).toList() ?? [];

      final escposData = formatter.formatSaleReceipt(
        shopName: 'My Shop',
        saleId: sale.id,
        items: items,
        subtotalCents: sale.subtotalCents,
        vatCents: sale.vatCents,
        totalCents: sale.totalCents,
        paymentMethod: sale.paymentMethod,
        currency: 'USD',
        printQrCode: true,
      );

      await ref.read(printerServiceProvider).queuePrintJob(
        receiptId: sale.id,
        escposData: escposData,
      );
    } catch (e) {
      // Silent fail - printing is optional
      debugPrint('Print queue error: $e');
    }
  }

  Future<void> _pickOtherMethod() async {
    const methods = [
      ('ONEMONEY', 'OneMoney', Icons.phone_android),
      ('INNBUCKS', 'InnBucks', Icons.account_balance_wallet),
      ('ZIPIT', 'ZIPIT (bank transfer)', Icons.account_balance),
      ('CARD', 'Card (Visa / Mastercard)', Icons.credit_card),
      ('CREDIT', 'On account (credit)', Icons.receipt_long_outlined),
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Text('Payment method', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
            for (final m in methods)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                  child: Icon(m.$3, color: const Color(0xFF4F46E5)),
                ),
                title: Text(m.$2, style: const TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, m.$1),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (picked != null) {
      await _checkout(picked);
    }
  }
}

class _ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _hovering = false;

  String get _stockStatus {
    final qty = widget.product.stockQty;
    if (qty <= 0) return 'Out';
    if (qty <= widget.product.reorderLevel) return 'Low';
    return 'OK';
  }

  Color get _stockColor {
    final qty = widget.product.stockQty;
    if (qty <= 0) return Colors.red;
    if (qty <= widget.product.reorderLevel) return Colors.orange;
    return Colors.green;
  }

  double get _margin {
    if (widget.product.costCents == 0 || widget.product.priceCents == 0) return 0;
    return ((widget.product.priceCents - widget.product.costCents) / widget.product.priceCents) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = widget.product.stockQty <= 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: isOutOfStock ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..translate(0.0, _hovering && !isOutOfStock ? -4.0 : 0.0),
          decoration: BoxDecoration(
            color: isOutOfStock ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOutOfStock
                  ? const Color(0xFFCBD5E1)
                  : _hovering ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
              width: 1.5
            ),
            boxShadow: !isOutOfStock && _hovering
                ? [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6))]
                : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Icon/Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: _stockColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isOutOfStock ? Icons.block_outlined : Icons.inventory_2_outlined,
                          color: _stockColor,
                          size: 20,
                        ),
                      ),
                      // Stock Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _stockColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _stockColor, width: 0.5),
                        ),
                        child: Text(
                          _stockStatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _stockColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Product Name
                  Text(
                    widget.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isOutOfStock ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // SKU (if available)
                  if (widget.product.sku != null)
                    Text(
                      'SKU: ${widget.product.sku}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                    ),

                  const Spacer(),

                  // Price and Margin
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Money.cents(widget.product.priceCents),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isOutOfStock ? const Color(0xFF94A3B8) : const Color(0xFF4F46E5),
                        ),
                      ),
                      if (widget.product.costCents > 0 && _margin > 0)
                        Text(
                          '${_margin.toStringAsFixed(0)}% margin',
                          style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Stock Quantity
                  Text(
                    '${widget.product.stockQty} ${widget.product.unit}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isOutOfStock ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              // Out of Stock Overlay
              if (isOutOfStock)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(Icons.do_not_disturb_on, color: Colors.white, size: 32),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptPreviewDialog extends StatelessWidget {
  final CartState cartState;
  final String method;

  const _ReceiptPreviewDialog({required this.cartState, required this.method});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 340,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 12))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long, size: 48, color: Color(0xFF64748B)),
                  const SizedBox(height: 16),
                  const Text('TILLPRO', style: TextStyle(fontFamily: 'monospace', fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  const Text('RECEIPT PREVIEW', style: TextStyle(fontFamily: 'monospace', fontSize: 14, color: Color(0xFF64748B))),
                  const SizedBox(height: 24),
                  const _DottedDivider(),
                  const SizedBox(height: 16),
                  
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: cartState.lines.length,
                      itemBuilder: (ctx, i) {
                        final l = cartState.lines[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text('${l.qty}x', style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(child: Text(l.product.name, style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
                              const SizedBox(width: 8),
                              Text(Money.cents(l.lineTotalCents), style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  const _DottedDivider(),
                  const SizedBox(height: 20),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL', style: TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(Money.cents(cartState.totalCents), style: const TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('PAYMENT', style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFF64748B))),
                      Text(method, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12))),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomRight: Radius.circular(12))),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Complete Sale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DottedDivider extends StatelessWidget {
  const _DottedDivider();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final boxWidth = constraints.constrainWidth();
      const dashWidth = 4.0;
      const dashSpace = 4.0;
      final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
      return Flex(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        direction: Axis.horizontal,
        children: List.generate(dashCount, (_) {
          return const SizedBox(
            width: dashWidth,
            height: 1,
            child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFCBD5E1))),
          );
        }),
      );
    });
  }
}
