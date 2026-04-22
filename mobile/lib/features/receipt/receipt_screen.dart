import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/db/local_db.dart';
import '../../core/fiscal/qr_builder.dart';
import '../../core/format/money.dart';
import '../../core/services/printer/printer_provider.dart';
import '../../core/services/printer/escpos_builder.dart';
import '../../core/widgets/printer/app_print_dialog.dart';
import '../../models/sale.dart';
import 'receipt_pdf.dart';

/// ZIMRA-compliant receipt screen.
///
/// Shows a full A5-like receipt preview with:
///   - Shop header (name, address, TIN, VAT)
///   - Line items with qty, unit price, VAT class, line total
///   - Subtotal (net), VAT per class, total
///   - Payment method + reference
///   - Fiscal receipt number + status pill
///   - ZIMRA QR (built client-side, overwritten when server accepts)
///
/// Actions:
///   - Share / save PDF
///   - Print via system print preview (pdf+printing package)
///   - Copy fiscal reference
class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, required this.saleId});
  final String saleId;

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  Sale? _sale;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Prefer local copy for instant render, then refresh from server for
    // authoritative fiscal fields.
    final local = LocalDb.salesBox.get(widget.saleId);
    if (local != null) {
      _sale = Sale.fromMap(Map<String, dynamic>.from(local));
      setState(() => _loading = false);
    }
    try {
      final r = await ref.read(apiClientProvider).get('/sales/${widget.saleId}');
      setState(() {
        _sale = _fromApi(Map<String, dynamic>.from(r.data as Map));
        _loading = false;
      });
    } catch (e) {
      if (_sale == null) {
        setState(() {
          _error = 'Offline and no local copy of this sale.';
          _loading = false;
        });
      }
    }
  }

  Sale _fromApi(Map<String, dynamic> m) {
    // Server SaleDto uses a slightly different shape (items array).
    return Sale.fromMap({
      ...m,
      'items': (m['items'] as List).map((e) => {
            ...Map<String, dynamic>.from(e as Map),
          }).toList(),
      'dirty': false,
    });
  }

  void _printToThermal(BuildContext context) {
    final isConnected = ref.read(printerConnectedProvider);

    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect a printer in Settings'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_sale == null) return;

    // Show preview
    showDialog(
      context: context,
      builder: (_) => AppPrintPreview(
        title: LocalDb.shopName ?? 'My Shop',
        receiptId: _sale!.id,
        totalCents: _sale!.totalCents,
        currency: 'USD',
        items: _sale!.items.map((item) => {
          'name': item.nameSnapshot,
          'quantity': item.qty,
          'unitPrice': item.unitPriceCents,
          'lineTotal': item.lineTotalCents,
        }).toList(),
        onPrint: () => _queuePrintJob(),
      ),
    );
  }

  Future<void> _queuePrintJob() async {
    if (_sale == null) return;

    try {
      final formatter = ReceiptFormatter();
      final escposData = formatter.formatSaleReceipt(
        shopName: LocalDb.shopName ?? 'My Shop',
        saleId: _sale!.id,
        items: _sale!.items.map((item) => {
          'name': item.nameSnapshot,
          'quantity': item.qty,
          'unitPrice': item.unitPriceCents,
          'lineTotal': item.lineTotalCents,
        }).toList(),
        subtotalCents: _sale!.subtotalCents,
        vatCents: _sale!.vatCents,
        totalCents: _sale!.totalCents,
        paymentMethod: _sale!.paymentMethod,
        shopAddress: LocalDb.shopAddress,
        shopPhone: LocalDb.shopPhone,
        currency: 'USD',
        printQrCode: true,
      );

      final jobId = await ref.read(printerServiceProvider).queuePrintJob(
        receiptId: _sale!.id,
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
            content: Text('Print error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Receipt', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        actions: [
          if (_sale != null) ...[
            PopupMenuButton(
              icon: const Icon(Icons.print_outlined),
              onSelected: (value) {
                if (value == 'pdf') {
                  ReceiptPdf.printNow(_sale!);
                } else if (value == 'thermal') {
                  _printToThermal(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Print to PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'thermal',
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Print Receipt'),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Share PDF',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => ReceiptPdf.share(_sale!),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(_error!)
              : _ReceiptBody(sale: _sale!),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView(this.msg);
  final String msg;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(msg, textAlign: TextAlign.center),
        ),
      );
}

class _ReceiptBody extends StatelessWidget {
  const _ReceiptBody({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final qr = sale.fiscalQrPayload ?? FiscalQr.build(sale);
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm').format(sale.clientCreatedAt.toLocal());

    final shopName = LocalDb.shopName ?? 'My Shop';
    final shopAddr = LocalDb.shopAddress ?? '';
    final shopPhone = LocalDb.shopPhone ?? '';
    final tin = LocalDb.tin ?? '';
    final vatNo = LocalDb.vatNumber ?? '';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Header ------------------------------------------
                    Text(shopName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700, fontSize: 18)),
                    if (shopAddr.isNotEmpty)
                      Text(shopAddr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54)),
                    if (shopPhone.isNotEmpty)
                      Text(shopPhone,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text('TIN: $tin    VAT: $vatNo',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 12)),
                    const SizedBox(height: 8),
                    const _Dashed(),
                    const SizedBox(height: 8),

                    // --- Receipt meta ------------------------------------
                    _row('Receipt', sale.fiscalReceiptNo ?? '(pending)'),
                    _row('Date', dateFmt),
                    _row('Till',
                        (sale.cashierId ?? '').substring(0, (sale.cashierId ?? '').length.clamp(0, 8))),
                    if (sale.customerName != null && sale.customerName!.isNotEmpty)
                      _row('Customer', sale.customerName!),
                    if (sale.customerTin != null && sale.customerTin!.isNotEmpty)
                      _row('Cust TIN', sale.customerTin!),
                    const SizedBox(height: 8),
                    const _Dashed(),
                    const SizedBox(height: 8),

                    // --- Line items --------------------------------------
                    ...sale.items.map((i) => _LineItem(i)),
                    const SizedBox(height: 8),
                    const _Dashed(),
                    const SizedBox(height: 8),

                    // --- Totals ------------------------------------------
                    _row('Subtotal (net)', Money.cents(sale.subtotalCents),
                        bold: false),
                    ..._vatLines(sale),
                    _row('TOTAL', Money.cents(sale.totalCents), bold: true),
                    const SizedBox(height: 8),
                    _row('Paid via', _paymentLabel(sale.paymentMethod)),
                    if (sale.paymentRef != null && sale.paymentRef!.isNotEmpty)
                      _row('Ref', sale.paymentRef!),

                    const SizedBox(height: 16),

                    // --- Fiscal footer + QR ------------------------------
                    _FiscalBadge(status: sale.fiscalStatus),
                    const SizedBox(height: 12),
                    Center(
                      child: QrImageView(
                        data: qr,
                        size: 160,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: SelectableText(
                        qr,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (sale.fiscalReference != null &&
                        sale.fiscalReference!.isNotEmpty)
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: sale.fiscalReference!));
                          },
                          icon: const Icon(Icons.copy_outlined, size: 16),
                          label: Text(
                              'ZIMRA ref: ${sale.fiscalReference}',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Thank you for your business.',
                        style: GoogleFonts.outfit(
                            fontStyle: FontStyle.italic,
                            color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _vatLines(Sale s) {
    final Map<String, int> vatByClass = {};
    for (final i in s.items) {
      vatByClass.update(i.vatClass, (v) => v + i.vatCents,
          ifAbsent: () => i.vatCents);
    }
    final entries = vatByClass.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) {
      return [_row('VAT', Money.cents(s.vatCents))];
    }
    return entries
        .map((e) => _row('VAT (${e.key})', Money.cents(e.value)))
        .toList();
  }

  String _paymentLabel(String m) => switch (m) {
        'CASH' => 'Cash',
        'ECOCASH' => 'EcoCash',
        'ONEMONEY' => 'OneMoney',
        'INNBUCKS' => 'InnBucks',
        'ZIPIT' => 'ZIPIT',
        'CARD' => 'Card',
        'CREDIT' => 'Credit (on account)',
        _ => m,
      };

  Widget _row(String l, String r, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
            child: Text(l,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    fontSize: bold ? 15 : 13)),
          ),
          Text(r,
              style: TextStyle(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  fontSize: bold ? 15 : 13)),
        ]),
      );
}

class _LineItem extends StatelessWidget {
  const _LineItem(this.i);
  final SaleItem i;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(i.nameSnapshot, style: const TextStyle(fontSize: 13))),
            Text(Money.cents(i.lineTotalCents),
                style: const TextStyle(
                    fontSize: 13,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ]),
          Row(children: [
            Expanded(
              child: Text(
                '  ${i.qty} × ${Money.cents(i.unitPriceCents)} · ${_shortVat(i.vatClass)}',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  String _shortVat(String c) => switch (c) {
        'STANDARD' => 'VAT S',
        'ZERO' => 'VAT Z',
        'EXEMPT' => 'VAT E',
        'LUXURY' => 'VAT L',
        _ => c,
      };
}

class _FiscalBadge extends StatelessWidget {
  const _FiscalBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'ACCEPTED' => (const Color(0xFFD1FAE5), const Color(0xFF065F46), 'ZIMRA ACCEPTED'),
      'PENDING' => (const Color(0xFFFFF7ED), const Color(0xFF9A3412), 'ZIMRA PENDING'),
      'OFFLINE' => (const Color(0xFFE0E7FF), const Color(0xFF3730A3), 'OFFLINE — WILL SUBMIT'),
      _ => (const Color(0xFFFEE2E2), const Color(0xFF991B1B), 'FISCAL ERROR'),
    };
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: TextStyle(
                color: fg, fontWeight: FontWeight.w600, fontSize: 11)),
      ),
    );
  }
}

class _Dashed extends StatelessWidget {
  const _Dashed();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: Color(0xFFCBD5E1),
                  width: 1,
                  style: BorderStyle.solid),
            ),
          ),
        ),
      );
}
