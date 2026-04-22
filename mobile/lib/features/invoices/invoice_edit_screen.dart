import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/db/local_db.dart';
import '../../core/format/money.dart';
import '../../models/invoice.dart';
import '../../models/product.dart';
import 'invoice_controller.dart';
import 'invoice_pdf.dart';

/// Invoice edit screen — draft, issue, record payments, share, void.
///
/// This screen is intentionally designed to be usable by any kind of SME:
///   - Retail: add a product line from the catalog (auto-fills description +
///     price + VAT class).
///   - Services: tap "Custom line" to type a free description ("Plumbing —
///     labour 4h", "Consultation", "Haircut and colour") with no product.
///   - Hybrid: both line types coexist in one invoice.
///
/// Totals are computed live on the client and mirror the server math. When
/// offline, saving creates an optimistic local row that the sync service
/// pushes later.
class InvoiceEditScreen extends ConsumerStatefulWidget {
  const InvoiceEditScreen({super.key, this.invoiceId});

  /// null → new invoice; otherwise edit existing.
  final String? invoiceId;

  @override
  ConsumerState<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends ConsumerState<InvoiceEditScreen> {
  late Invoice _inv;
  final _customerName = TextEditingController();
  final _customerTin = TextEditingController();
  final _customerEmail = TextEditingController();
  final _customerAddress = TextEditingController();
  final _notes = TextEditingController();
  final _terms = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing =
        widget.invoiceId == null ? null : LocalDb.findInvoice(widget.invoiceId!);
    _inv = existing ??
        Invoice(
          id: _uuid(),
          kind: 'INVOICE',
          status: 'DRAFT',
          issueDate: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 14)),
          currency: LocalDb.currency,
          items: [],
          terms: 'Payment due within 14 days of invoice date.',
        );
    _customerName.text = _inv.customerName ?? '';
    _customerTin.text = _inv.customerTin ?? '';
    _customerEmail.text = _inv.customerEmail ?? '';
    _customerAddress.text = _inv.customerAddress ?? '';
    _notes.text = _inv.notes ?? '';
    _terms.text = _inv.terms ?? '';
  }

  @override
  void dispose() {
    _customerName.dispose();
    _customerTin.dispose();
    _customerEmail.dispose();
    _customerAddress.dispose();
    _notes.dispose();
    _terms.dispose();
    super.dispose();
  }

  String _uuid() {
    // Tiny UUID-v4-ish for client use. Backend accepts any UUID.
    final r = Random();
    String hex(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + r.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
  }

  bool get _locked =>
      _inv.status == 'PAID' ||
      _inv.status == 'VOIDED' ||
      _inv.kind == 'CREDIT_NOTE';

  void _syncFromControllers() {
    _inv.customerName = _textOrNull(_customerName.text);
    _inv.customerTin = _textOrNull(_customerTin.text);
    _inv.customerEmail = _textOrNull(_customerEmail.text);
    _inv.customerAddress = _textOrNull(_customerAddress.text);
    _inv.notes = _textOrNull(_notes.text);
    _inv.terms = _textOrNull(_terms.text);
  }

  String? _textOrNull(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _saveDraft() async {
    _syncFromControllers();
    await ref.read(invoiceListProvider.notifier).saveDraft(_inv);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft saved')),
    );
    setState(() {});
  }

  Future<void> _issue() async {
    if (_inv.items.isEmpty) {
      _snack('Add at least one line item first');
      return;
    }
    _syncFromControllers();
    final fresh = await ref.read(invoiceListProvider.notifier).issue(_inv);
    if (fresh != null) setState(() => _inv = fresh);
    if (!mounted) return;
    _snack(fresh == null
        ? 'Issued locally — will sync when online'
        : 'Invoice ${fresh.number} issued');
  }

  Future<void> _addPayment() async {
    final amountCtl = TextEditingController(
        text: (_inv.balanceCents / 100).toStringAsFixed(2));
    final refCtl = TextEditingController();
    String method = 'CASH';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Record payment',
                  style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '${LocalDb.currency} ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Method'),
                items: const [
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'ECOCASH', child: Text('EcoCash')),
                  DropdownMenuItem(value: 'ONEMONEY', child: Text('OneMoney')),
                  DropdownMenuItem(value: 'INNBUCKS', child: Text('InnBucks')),
                  DropdownMenuItem(value: 'ZIPIT', child: Text('ZIPIT')),
                  DropdownMenuItem(value: 'CARD', child: Text('Card')),
                  DropdownMenuItem(
                      value: 'BANK_TRANSFER', child: Text('Bank transfer')),
                ],
                onChanged: (v) => setModal(() => method = v ?? 'CASH'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refCtl,
                decoration: const InputDecoration(
                  labelText: 'Reference (optional)',
                  hintText: 'e.g. txn id, cheque #',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Record'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final cents = ((double.tryParse(amountCtl.text) ?? 0) * 100).round();
    if (cents <= 0) return;
    final payment = InvoicePayment(
      id: _uuid(),
      amountCents: cents,
      method: method,
      reference: _textOrNull(refCtl.text),
    );
    final fresh = await ref
        .read(invoiceListProvider.notifier)
        .recordPayment(_inv.id, payment);
    if (fresh != null) setState(() => _inv = fresh);
    if (mounted) _snack('Payment recorded');
  }

  Future<void> _void() async {
    final reasonCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void invoice?'),
        content: TextField(
          controller: reasonCtl,
          decoration: const InputDecoration(
              labelText: 'Reason', hintText: 'e.g. customer cancelled'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Void')),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(invoiceListProvider.notifier)
        .voidInvoice(_inv.id, _textOrNull(reasonCtl.text));
    if (!mounted) return;
    final fresh = LocalDb.findInvoice(_inv.id);
    if (fresh != null) setState(() => _inv = fresh);
    _snack('Invoice voided');
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m)));
  }

  void _addCustomLine() async {
    final line = await _editLine(
      context,
      InvoiceItem(
        id: _uuid(),
        description: '',
        qty: 1,
        unitPriceCents: 0,
      ),
    );
    if (line != null) {
      setState(() => _inv.items = [..._inv.items, line]);
    }
  }

  Future<void> _addProductLine() async {
    final products = LocalDb.allProducts();
    if (products.isEmpty) {
      _snack('No products in catalog yet');
      return;
    }
    final p = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: _ProductPicker(products: products),
      ),
    );
    if (p == null) return;
    final line = InvoiceItem(
      id: _uuid(),
      productId: p.id,
      description: p.name,
      qty: 1,
      unit: 'pc',
      unitPriceCents: p.priceCents,
      vatClass: p.vatClass,
    );
    setState(() => _inv.items = [..._inv.items, line]);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');
    final isNew = widget.invoiceId == null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isNew
              ? 'New ${_kindLabel(_inv.kind)}'
              : _inv.number ?? 'Draft ${_inv.id.substring(0, 6).toUpperCase()}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) async {
              switch (v) {
                case 'pdf':
                  _syncFromControllers();
                  await InvoicePdf.share(_inv);
                  break;
                case 'print':
                  _syncFromControllers();
                  await InvoicePdf.printNow(_inv);
                  break;
                case 'void':
                  _void();
                  break;
                case 'copy':
                  Clipboard.setData(
                      ClipboardData(text: _inv.number ?? _inv.id));
                  _snack('Copied');
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                      leading: Icon(Icons.picture_as_pdf_rounded),
                      title: Text('Share PDF'))),
              const PopupMenuItem(
                  value: 'print',
                  child: ListTile(
                      leading: Icon(Icons.print_rounded),
                      title: Text('Print'))),
              const PopupMenuItem(
                  value: 'copy',
                  child: ListTile(
                      leading: Icon(Icons.copy_rounded),
                      title: Text('Copy number'))),
              if (_inv.status != 'VOIDED')
                const PopupMenuItem(
                    value: 'void',
                    child: ListTile(
                        leading: Icon(Icons.block_rounded),
                        title: Text('Void'))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
        children: [
          _HeaderCard(
            inv: _inv,
            onKindChange: _locked
                ? null
                : (k) => setState(() => _inv.kind = k),
            onIssueDate: _locked
                ? null
                : () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _inv.issueDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _inv.issueDate = d);
                  },
            onDueDate: _locked
                ? null
                : () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _inv.dueDate ?? _inv.issueDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _inv.dueDate = d);
                  },
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Bill to'),
          const SizedBox(height: 8),
          _Field(label: 'Customer name', ctl: _customerName),
          _Field(label: 'TIN / VAT no.', ctl: _customerTin),
          _Field(label: 'Email', ctl: _customerEmail),
          _Field(label: 'Address', ctl: _customerAddress, maxLines: 2),
          const SizedBox(height: 16),
          Row(
            children: [
              _SectionHeader(title: 'Line items'),
              const Spacer(),
              if (!_locked)
                TextButton.icon(
                  onPressed: _addProductLine,
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('Product'),
                ),
              if (!_locked)
                TextButton.icon(
                  onPressed: _addCustomLine,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Custom'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_inv.items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text('No line items yet. Add a product or custom line.',
                    style: GoogleFonts.outfit(
                        color: Colors.grey.shade600, fontSize: 13),
                    textAlign: TextAlign.center),
              ),
            )
          else
            for (final item in _inv.items)
              _LineTile(
                item: item,
                locked: _locked,
                onEdit: () async {
                  final r = await _editLine(context, item);
                  if (r != null) {
                    setState(() {
                      final idx = _inv.items.indexWhere((i) => i.id == item.id);
                      if (idx >= 0) _inv.items[idx] = r;
                    });
                  }
                },
                onDelete: () => setState(
                    () => _inv.items = _inv.items.where((i) => i.id != item.id).toList()),
              ),
          const SizedBox(height: 12),
          _TotalsCard(inv: _inv),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Notes & terms'),
          const SizedBox(height: 8),
          _Field(label: 'Notes (visible on invoice)', ctl: _notes, maxLines: 2),
          _Field(label: 'Payment terms', ctl: _terms, maxLines: 2),
          if (_inv.payments.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionHeader(title: 'Payments received'),
            for (final p in _inv.payments)
              ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline_rounded,
                    color: Colors.green),
                title: Text(Money.cents(p.amountCents),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${p.method}${p.reference == null ? '' : ' · ${p.reference}'} · ${df.format(p.paidAt)}'),
              ),
          ],
        ],
      ),
      bottomNavigationBar: _BottomBar(
        inv: _inv,
        onSaveDraft: _locked ? null : _saveDraft,
        onIssue: (_locked || _inv.status != 'DRAFT') ? null : _issue,
        onRecordPayment: (_inv.status == 'SENT' ||
                _inv.status == 'PARTIAL' ||
                _inv.status == 'OVERDUE')
            ? _addPayment
            : null,
      ),
    );
  }

  String _kindLabel(String k) => switch (k) {
        'QUOTE' => 'Quote',
        'PROFORMA' => 'Pro-forma',
        'CREDIT_NOTE' => 'Credit note',
        _ => 'Invoice',
      };

  Future<InvoiceItem?> _editLine(BuildContext ctx, InvoiceItem item) async {
    final desc = TextEditingController(text: item.description);
    final qty = TextEditingController(text: item.qty.toString());
    final unit = TextEditingController(text: item.unit);
    final price =
        TextEditingController(text: (item.unitPriceCents / 100).toStringAsFixed(2));
    final discount = TextEditingController(
        text: (item.discountCents / 100).toStringAsFixed(2));
    String vatClass = item.vatClass;
    return await showModalBottomSheet<InvoiceItem>(
      context: ctx,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (mctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(mctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (mctx, setModal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Line item',
                  style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: desc,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. Plumbing — labour 4h',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: qty,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Qty'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Unit price'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: discount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Line discount'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: vatClass,
                      decoration: const InputDecoration(labelText: 'VAT'),
                      items: const [
                        DropdownMenuItem(
                            value: 'STANDARD', child: Text('Standard 15%')),
                        DropdownMenuItem(value: 'ZERO', child: Text('Zero 0%')),
                        DropdownMenuItem(value: 'EXEMPT', child: Text('Exempt')),
                        DropdownMenuItem(
                            value: 'LUXURY', child: Text('Luxury 25%')),
                      ],
                      onChanged: (v) =>
                          setModal(() => vatClass = v ?? 'STANDARD'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(mctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final q = num.tryParse(qty.text) ?? 1;
                        final pc =
                            ((double.tryParse(price.text) ?? 0) * 100).round();
                        final dc = ((double.tryParse(discount.text) ?? 0) * 100)
                            .round();
                        final out = InvoiceItem(
                          id: item.id,
                          productId: item.productId,
                          description: desc.text.trim(),
                          qty: q,
                          unit: unit.text.trim().isEmpty ? 'pc' : unit.text.trim(),
                          unitPriceCents: pc,
                          discountCents: dc,
                          vatClass: vatClass,
                        );
                        Navigator.pop(mctx, out);
                      },
                      child: const Text('Save line'),
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.inv,
    required this.onKindChange,
    required this.onIssueDate,
    required this.onDueDate,
  });
  final Invoice inv;
  final ValueChanged<String>? onKindChange;
  final VoidCallback? onIssueDate;
  final VoidCallback? onDueDate;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final k in const [
                  ('INVOICE', 'Invoice'),
                  ('QUOTE', 'Quote'),
                  ('PROFORMA', 'Pro-forma'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(k.$2),
                      selected: inv.kind == k.$1,
                      onSelected: onKindChange == null
                          ? null
                          : (_) => onKindChange!(k.$1),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onIssueDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Issue date',
                              style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.grey.shade600)),
                          const SizedBox(height: 2),
                          Text(df.format(inv.issueDate),
                              style: GoogleFonts.outfit(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: onDueDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Due date',
                              style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.grey.shade600)),
                          const SizedBox(height: 2),
                          Text(
                              inv.dueDate == null
                                  ? 'No due date'
                                  : df.format(inv.dueDate!),
                              style: GoogleFonts.outfit(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(title,
      style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700));
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.ctl, this.maxLines = 1});
  final String label;
  final TextEditingController ctl;
  final int maxLines;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: ctl,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label, isDense: true),
        ),
      );
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.item,
    required this.locked,
    required this.onEdit,
    required this.onDelete,
  });
  final InvoiceItem item;
  final bool locked;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: locked ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade50,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        child: ListTile(
          onTap: locked ? null : onEdit,
          title: Text(
              item.description.isEmpty ? '(no description)' : item.description,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          subtitle: Text(
              '${item.qty} ${item.unit} × ${Money.cents(item.unitPriceCents)}'
              '${item.discountCents > 0 ? ' − ${Money.cents(item.discountCents)}' : ''}'
              ' · ${item.vatClass}',
              style: GoogleFonts.outfit(fontSize: 12)),
          trailing: Text(Money.cents(item.lineTotalCents),
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.inv});
  final Invoice inv;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _row('Subtotal (net)', Money.cents(inv.subtotalCents)),
            _row('VAT', Money.cents(inv.vatCents)),
            if (inv.discountCents > 0)
              _row('Discount', '− ${Money.cents(inv.discountCents)}'),
            const Divider(height: 16),
            _row('Total', Money.cents(inv.totalCents), big: true),
            if (inv.paidCents > 0) ...[
              _row('Paid', '− ${Money.cents(inv.paidCents)}'),
              _row('Balance', Money.cents(inv.balanceCents),
                  big: true, accent: Colors.orange),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool big = false, Color? accent}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: big ? 15 : 13,
                  fontWeight: big ? FontWeight.w600 : FontWeight.w500,
                  color: Colors.grey.shade700)),
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: big ? 18 : 13,
                  fontWeight: big ? FontWeight.w700 : FontWeight.w600,
                  color: accent)),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.inv,
    required this.onSaveDraft,
    required this.onIssue,
    required this.onRecordPayment,
  });
  final Invoice inv;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onIssue;
  final VoidCallback? onRecordPayment;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSaveDraft,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: onRecordPayment != null
                  ? FilledButton.icon(
                      onPressed: onRecordPayment,
                      icon: const Icon(Icons.payments_rounded),
                      label: Text(
                          'Record payment · ${Money.cents(inv.balanceCents)}'),
                    )
                  : FilledButton.icon(
                      onPressed: onIssue,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                          inv.kind == 'QUOTE' ? 'Send quote' : 'Issue invoice'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.products});
  final List<Product> products;
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.products
        .where((p) =>
            _q.isEmpty ||
            p.name.toLowerCase().contains(_q) ||
            (p.sku ?? '').toLowerCase().contains(_q))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search products',
              isDense: true,
            ),
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final p = filtered[i];
              return ListTile(
                title: Text(p.name,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                subtitle: Text('${p.sku} · ${p.vatClass}',
                    style: GoogleFonts.outfit(fontSize: 12)),
                trailing: Text(Money.cents(p.priceCents),
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                onTap: () => Navigator.pop(ctx, p),
              );
            },
          ),
        ),
      ],
    );
  }
}
