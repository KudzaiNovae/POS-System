import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../core/db/local_db.dart';
import '../../core/fiscal/qr_builder.dart';
import '../../core/format/money.dart';
import '../../models/sale.dart';

/// Renders a ZIMRA-compliant PDF receipt at thermal-80mm width, plus helpers
/// to print via the system print dialog or share/save to disk.
///
/// We target 80mm (≈ 226pt) because that's the common width for the Epson
/// TM-T20III / XPrinter XP-365B thermal receipt printers we tested against.
/// The same layout falls back to an A6 / A5 print on regular printers.
class ReceiptPdf {
  static Future<void> printNow(Sale sale) async {
    final doc = await build(sale);
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  static Future<void> share(Sale sale) async {
    final doc = await build(sale);
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'receipt-${sale.fiscalReceiptNo ?? sale.id.substring(0, 8)}.pdf',
    );
  }

  static Future<pw.Document> build(Sale sale) async {
    final doc = pw.Document(title: 'TillPro Receipt');
    final qrData = sale.fiscalQrPayload ?? FiscalQr.build(sale);
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm')
        .format(sale.clientCreatedAt.toLocal());

    // Sum VAT per class for the summary block.
    final Map<String, int> vatByClass = {};
    for (final i in sale.items) {
      vatByClass.update(i.vatClass, (v) => v + i.vatCents,
          ifAbsent: () => i.vatCents);
    }

    // 80mm = 226.7pt; leave a hair of margin so cheap thermal printers don't
    // clip the side. For A4 laser printing, printing will scale sensibly.
    final pageFormat = PdfPageFormat(
      220,
      double.infinity,
      marginAll: 8,
    );

    doc.addPage(pw.Page(
      pageFormat: pageFormat,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header block
          pw.Text(
            (LocalDb.shopName ?? 'My Shop').toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          if ((LocalDb.shopAddress ?? '').isNotEmpty)
            pw.Text(LocalDb.shopAddress!,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9)),
          if ((LocalDb.shopPhone ?? '').isNotEmpty)
            pw.Text(LocalDb.shopPhone!,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            'TIN: ${LocalDb.tin ?? ''}    VAT: ${LocalDb.vatNumber ?? ''}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          _rule(),

          _kv('Receipt', sale.fiscalReceiptNo ?? '(pending)'),
          _kv('Date', dateFmt),
          if ((sale.customerName ?? '').isNotEmpty)
            _kv('Customer', sale.customerName!),
          if ((sale.customerTin ?? '').isNotEmpty)
            _kv('Cust TIN', sale.customerTin!),

          _rule(),

          ...sale.items.map((i) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(children: [
                    pw.Expanded(
                      child: pw.Text(i.nameSnapshot,
                          style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Text(Money.cents(i.lineTotalCents),
                        style: const pw.TextStyle(fontSize: 9)),
                  ]),
                  pw.Text(
                    '  ${i.qty} x ${Money.cents(i.unitPriceCents)}  [${_vatCode(i.vatClass)}]',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              )),

          _rule(),

          _kv('Subtotal', Money.cents(sale.subtotalCents)),
          ...vatByClass.entries.where((e) => e.value > 0).map(
                (e) => _kv('VAT (${e.key})', Money.cents(e.value)),
              ),
          _kv('TOTAL', Money.cents(sale.totalCents), bold: true),
          _kv('Paid', _paymentLabel(sale.paymentMethod)),
          if ((sale.paymentRef ?? '').isNotEmpty)
            _kv('Ref', sale.paymentRef!),

          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text(_fiscalBadge(sale.fiscalStatus),
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrData,
              width: 120,
              height: 120,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(qrData,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 6)),
          if ((sale.fiscalReference ?? '').isNotEmpty)
            pw.Center(
              child: pw.Text('ZIMRA ref: ${sale.fiscalReference}',
                  style: const pw.TextStyle(fontSize: 8)),
            ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text('Thank you for your business.',
                style: pw.TextStyle(
                    fontSize: 9, fontStyle: pw.FontStyle.italic)),
          ),
        ],
      ),
    ));
    return doc;
  }

  static pw.Widget _rule() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Divider(height: 1, thickness: 0.5, color: PdfColors.grey),
      );

  static pw.Widget _kv(String k, String v, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(children: [
        pw.Expanded(
            child: pw.Text(k,
                style: pw.TextStyle(
                    fontSize: bold ? 11 : 9,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
        pw.Text(v,
            style: pw.TextStyle(
                fontSize: bold ? 11 : 9,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ]),
    );
  }

  static String _vatCode(String c) => switch (c) {
        'STANDARD' => 'S',
        'ZERO' => 'Z',
        'EXEMPT' => 'E',
        'LUXURY' => 'L',
        _ => c,
      };

  static String _paymentLabel(String m) => switch (m) {
        'CASH' => 'Cash',
        'ECOCASH' => 'EcoCash',
        'ONEMONEY' => 'OneMoney',
        'INNBUCKS' => 'InnBucks',
        'ZIPIT' => 'ZIPIT',
        'CARD' => 'Card',
        'CREDIT' => 'Credit',
        _ => m,
      };

  static String _fiscalBadge(String s) => switch (s) {
        'ACCEPTED' => '*** ZIMRA ACCEPTED ***',
        'PENDING' => '*** ZIMRA PENDING ***',
        'OFFLINE' => '*** OFFLINE - WILL SUBMIT ***',
        _ => '*** FISCAL ERROR ***',
      };
}
