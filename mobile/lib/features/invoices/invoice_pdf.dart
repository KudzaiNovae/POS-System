import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/db/local_db.dart';
import '../../core/format/money.dart';
import '../../models/invoice.dart';

/// Professional A4 invoice / quote / pro-forma / credit-note renderer.
///
/// Unlike the 80mm thermal receipt, this document is designed to be emailed
/// or printed on office paper. It includes:
///   - Shop letterhead (name / address / phone / TIN / VAT)
///   - Customer "bill to" block
///   - Line-item table with qty / unit price / VAT / amount
///   - Totals block (subtotal net, VAT broken out by class, discount, total)
///   - Payment ledger (when present)
///   - Notes + terms
///   - Bank-payment details footer (pulled from meta)
///
/// The same `build()` function produces every document kind — only header
/// text, tinting, and sign-convention for credit notes differ.
class InvoicePdf {
  static Future<void> printNow(Invoice inv) async {
    final doc = await build(inv);
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  static Future<void> share(Invoice inv) async {
    final doc = await build(inv);
    final number = inv.number ?? inv.id.substring(0, 8);
    final prefix = _filePrefix(inv.kind);
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '$prefix-$number.pdf',
    );
  }

  static String _filePrefix(String kind) => switch (kind) {
        'QUOTE' => 'quote',
        'PROFORMA' => 'proforma',
        'CREDIT_NOTE' => 'credit-note',
        _ => 'invoice',
      };

  static String _docTitle(String kind) => switch (kind) {
        'QUOTE' => 'QUOTATION',
        'PROFORMA' => 'PRO-FORMA INVOICE',
        'CREDIT_NOTE' => 'CREDIT NOTE',
        _ => 'TAX INVOICE',
      };

  static PdfColor _accent(String kind) => switch (kind) {
        'QUOTE' => const PdfColor.fromInt(0xFF0EA5E9),
        'PROFORMA' => const PdfColor.fromInt(0xFF8B5CF6),
        'CREDIT_NOTE' => const PdfColor.fromInt(0xFFEF4444),
        _ => const PdfColor.fromInt(0xFF6366F1),
      };

  static Future<pw.Document> build(Invoice inv) async {
    final doc = pw.Document(title: 'TillPro ${_docTitle(inv.kind)}');
    final accent = _accent(inv.kind);
    final slate = const PdfColor.fromInt(0xFF334155);
    final mute = const PdfColor.fromInt(0xFF64748B);
    final line = const PdfColor.fromInt(0xFFE2E8F0);
    final df = DateFormat('d MMMM yyyy');

    // Group VAT per class for the summary rows.
    final Map<String, int> vatByClass = {};
    for (final i in inv.items) {
      if (i.vatClass == 'STANDARD' || i.vatClass == 'LUXURY') {
        final net = _netOf(i);
        final vat = i.lineTotalCents - net;
        vatByClass.update(i.vatClass, (v) => v + vat, ifAbsent: () => vat);
      }
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 40),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : _continuationHeader(inv, accent, slate),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${LocalDb.shopName ?? 'TillPro'} · ${inv.number ?? 'DRAFT'}',
              style: pw.TextStyle(fontSize: 8, color: mute),
            ),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: mute)),
          ],
        ),
      ),
      build: (ctx) => [
        _header(inv, accent, slate, mute, df),
        pw.SizedBox(height: 18),
        _parties(inv, slate, mute, line),
        pw.SizedBox(height: 16),
        _itemsTable(inv, accent, slate, mute, line),
        pw.SizedBox(height: 10),
        _totals(inv, vatByClass, accent, slate, mute, line),
        if (inv.payments.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          _paymentsBlock(inv, slate, mute, line, df),
        ],
        if ((inv.notes ?? '').isNotEmpty || (inv.terms ?? '').isNotEmpty) ...[
          pw.SizedBox(height: 16),
          _notesBlock(inv, slate, mute, line),
        ],
        pw.SizedBox(height: 20),
        _paymentFooter(inv, accent, slate, mute, line),
      ],
    ));

    return doc;
  }

  // ---- header (first page) ----
  static pw.Widget _header(Invoice inv, PdfColor accent, PdfColor slate,
      PdfColor mute, DateFormat df) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                (LocalDb.shopName ?? 'My Shop').toUpperCase(),
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold, color: slate),
              ),
              if ((LocalDb.shopAddress ?? '').isNotEmpty)
                pw.Text(LocalDb.shopAddress!,
                    style: pw.TextStyle(fontSize: 9, color: mute)),
              if ((LocalDb.shopPhone ?? '').isNotEmpty)
                pw.Text('Tel: ${LocalDb.shopPhone!}',
                    style: pw.TextStyle(fontSize: 9, color: mute)),
              if ((LocalDb.ownerEmail ?? '').isNotEmpty)
                pw.Text(LocalDb.ownerEmail!,
                    style: pw.TextStyle(fontSize: 9, color: mute)),
              pw.SizedBox(height: 4),
              if ((LocalDb.tin ?? '').isNotEmpty)
                pw.Text('TIN: ${LocalDb.tin}',
                    style: pw.TextStyle(fontSize: 9, color: mute)),
              if ((LocalDb.vatNumber ?? '').isNotEmpty)
                pw.Text('VAT Reg: ${LocalDb.vatNumber}',
                    style: pw.TextStyle(fontSize: 9, color: mute)),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: accent,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(_docTitle(inv.kind),
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 8),
            pw.Text(inv.number ?? 'DRAFT',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold, color: slate)),
            pw.SizedBox(height: 4),
            pw.Text('Issue date: ${df.format(inv.issueDate)}',
                style: pw.TextStyle(fontSize: 9, color: mute)),
            if (inv.dueDate != null)
              pw.Text('Due date: ${df.format(inv.dueDate!)}',
                  style: pw.TextStyle(fontSize: 9, color: mute)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(_statusTint(inv.status)),
                borderRadius: pw.BorderRadius.circular(20),
              ),
              child: pw.Text(inv.status,
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(_statusInk(inv.status)))),
            ),
          ],
        ),
      ],
    );
  }

  static int _statusTint(String s) => switch (s) {
        'PAID' => 0xFFDCFCE7,
        'PARTIAL' => 0xFFFEF3C7,
        'OVERDUE' => 0xFFFEE2E2,
        'VOIDED' => 0xFFE2E8F0,
        'DRAFT' => 0xFFF1F5F9,
        _ => 0xFFE0F2FE,
      };

  static int _statusInk(String s) => switch (s) {
        'PAID' => 0xFF166534,
        'PARTIAL' => 0xFF92400E,
        'OVERDUE' => 0xFF991B1B,
        'VOIDED' => 0xFF475569,
        'DRAFT' => 0xFF475569,
        _ => 0xFF0369A1,
      };

  static pw.Widget _continuationHeader(
      Invoice inv, PdfColor accent, PdfColor slate) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: accent, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(LocalDb.shopName ?? 'My Shop',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold, color: slate)),
          pw.Text('${_docTitle(inv.kind)} · ${inv.number ?? 'DRAFT'}',
              style: pw.TextStyle(fontSize: 10, color: slate)),
        ],
      ),
    );
  }

  // ---- parties ----
  static pw.Widget _parties(
      Invoice inv, PdfColor slate, PdfColor mute, PdfColor line) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: line),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('BILL TO',
                    style: pw.TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.2,
                        color: mute,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(
                    (inv.customerName?.isNotEmpty ?? false)
                        ? inv.customerName!
                        : 'Walk-in customer',
                    style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: slate)),
                if ((inv.customerAddress ?? '').isNotEmpty)
                  pw.Text(inv.customerAddress!,
                      style: pw.TextStyle(fontSize: 9, color: mute)),
                if ((inv.customerEmail ?? '').isNotEmpty)
                  pw.Text(inv.customerEmail!,
                      style: pw.TextStyle(fontSize: 9, color: mute)),
                if ((inv.customerTin ?? '').isNotEmpty)
                  pw.Text('TIN: ${inv.customerTin}',
                      style: pw.TextStyle(fontSize: 9, color: mute)),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PAYMENT SUMMARY',
                    style: pw.TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.2,
                        color: mute,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Currency: ${inv.currency}',
                    style: pw.TextStyle(fontSize: 9, color: slate)),
                pw.Text('Total: ${Money.cents(inv.totalCents)}',
                    style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: slate)),
                if (inv.paidCents > 0)
                  pw.Text('Paid: ${Money.cents(inv.paidCents)}',
                      style: pw.TextStyle(fontSize: 9, color: mute)),
                if (inv.balanceCents > 0 && inv.kind == 'INVOICE')
                  pw.Text('Balance due: ${Money.cents(inv.balanceCents)}',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFFD97706))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- items table ----
  static pw.Widget _itemsTable(Invoice inv, PdfColor accent, PdfColor slate,
      PdfColor mute, PdfColor line) {
    final headers = ['#', 'Description', 'Qty', 'Unit price', 'VAT', 'Amount'];
    final rows = <List<String>>[];
    for (var idx = 0; idx < inv.items.length; idx++) {
      final i = inv.items[idx];
      rows.add([
        '${idx + 1}',
        _descriptionCell(i),
        '${i.qty} ${i.unit}',
        Money.cents(i.unitPriceCents),
        _vatCode(i.vatClass),
        Money.cents(i.lineTotalCents),
      ]);
    }
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: const {
        0: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.center,
        5: pw.Alignment.centerRight,
      },
      headerDecoration: pw.BoxDecoration(color: accent),
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      cellStyle: pw.TextStyle(fontSize: 9, color: slate),
      headerAlignments: const {
        0: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.center,
        5: pw.Alignment.centerRight,
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      columnWidths: {
        0: const pw.FixedColumnWidth(22),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.6),
        4: const pw.FlexColumnWidth(0.8),
        5: const pw.FlexColumnWidth(1.8),
      },
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: line, width: 0.5),
        bottom: pw.BorderSide(color: line, width: 0.5),
      ),
    );
  }

  static String _descriptionCell(InvoiceItem i) {
    if (i.discountCents > 0) {
      return '${i.description}\n(discount ${Money.cents(i.discountCents)})';
    }
    return i.description;
  }

  static String _vatCode(String c) => switch (c) {
        'STANDARD' => 'S',
        'ZERO' => 'Z',
        'EXEMPT' => 'E',
        'LUXURY' => 'L',
        _ => '-',
      };

  // ---- totals ----
  static pw.Widget _totals(Invoice inv, Map<String, int> vatByClass,
      PdfColor accent, PdfColor slate, PdfColor mute, PdfColor line) {
    final rows = <pw.Widget>[
      _totalRow('Subtotal (net)', Money.cents(inv.subtotalCents), slate, mute),
    ];
    for (final entry in vatByClass.entries) {
      rows.add(_totalRow(
          'VAT ${entry.key == 'STANDARD' ? '15%' : '25%'}',
          Money.cents(entry.value),
          slate,
          mute));
    }
    if (inv.discountCents > 0) {
      rows.add(_totalRow(
          'Invoice discount', '- ${Money.cents(inv.discountCents)}', slate, mute));
    }
    rows.add(pw.Divider(color: line, height: 10));
    rows.add(_totalRow('TOTAL ${inv.currency}', Money.cents(inv.totalCents),
        slate, mute,
        big: true, accent: accent));
    if (inv.paidCents > 0) {
      rows.add(_totalRow('Amount paid', '- ${Money.cents(inv.paidCents)}',
          slate, mute));
      rows.add(_totalRow('BALANCE DUE', Money.cents(inv.balanceCents), slate, mute,
          big: true, accent: const PdfColor.fromInt(0xFFD97706)));
    }

    return pw.Row(
      children: [
        pw.Expanded(child: pw.SizedBox()),
        pw.Container(
          width: 260,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ],
    );
  }

  static pw.Widget _totalRow(String label, String value, PdfColor slate,
      PdfColor mute,
      {bool big = false, PdfColor? accent}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: big ? 11 : 9,
                  color: big ? slate : mute,
                  fontWeight: big ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: big ? 13 : 9,
                  color: accent ?? slate,
                  fontWeight: big ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  // ---- payments block ----
  static pw.Widget _paymentsBlock(Invoice inv, PdfColor slate, PdfColor mute,
      PdfColor line, DateFormat df) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: line),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('PAYMENTS RECEIVED',
              style: pw.TextStyle(
                  fontSize: 8,
                  letterSpacing: 1.2,
                  color: mute,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          for (final p in inv.payments)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                        '${df.format(p.paidAt)} — ${p.method}${p.reference == null ? '' : ' (${p.reference})'}',
                        style: pw.TextStyle(fontSize: 9, color: slate)),
                  ),
                  pw.Text(Money.cents(p.amountCents),
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: slate)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---- notes & terms ----
  static pw.Widget _notesBlock(
      Invoice inv, PdfColor slate, PdfColor mute, PdfColor line) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if ((inv.notes ?? '').isNotEmpty)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('NOTES',
                    style: pw.TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.2,
                        color: mute,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(inv.notes!,
                    style: pw.TextStyle(fontSize: 9, color: slate)),
              ],
            ),
          ),
        if ((inv.notes ?? '').isNotEmpty && (inv.terms ?? '').isNotEmpty)
          pw.SizedBox(width: 18),
        if ((inv.terms ?? '').isNotEmpty)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PAYMENT TERMS',
                    style: pw.TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.2,
                        color: mute,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(inv.terms!,
                    style: pw.TextStyle(fontSize: 9, color: slate)),
              ],
            ),
          ),
      ],
    );
  }

  // ---- payment footer ----
  static pw.Widget _paymentFooter(Invoice inv, PdfColor accent, PdfColor slate,
      PdfColor mute, PdfColor line) {
    // Zim-specific pay rails — we show the common ones so customers on the
    // receiving end know how to settle. TIN/VAT already printed in header.
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border(left: pw.BorderSide(color: accent, width: 3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('HOW TO PAY',
              style: pw.TextStyle(
                  fontSize: 8,
                  letterSpacing: 1.2,
                  color: mute,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(
              'Please make payment to ${LocalDb.shopName ?? 'our shop'}.  '
              'Quote reference: ${inv.number ?? inv.id.substring(0, 8)}',
              style: pw.TextStyle(fontSize: 9, color: slate)),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              if ((LocalDb.shopPhone ?? '').isNotEmpty)
                pw.Expanded(
                  child: pw.Text(
                      'Mobile money (EcoCash / OneMoney / InnBucks): ${LocalDb.shopPhone}',
                      style: pw.TextStyle(fontSize: 9, color: slate)),
                ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
              'Generated by TillPro · ${DateFormat('d MMM yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 7, color: mute)),
        ],
      ),
    );
  }

  // ---- net-of helper for VAT breakdown (client mirror of server math) ----
  static int _netOf(InvoiceItem i) {
    final gross = i.lineTotalCents;
    switch (i.vatClass) {
      case 'STANDARD':
        return (gross * 10000) ~/ (10000 + 1500);
      case 'LUXURY':
        return (gross * 10000) ~/ (10000 + 2500);
      default:
        return gross;
    }
  }
}
