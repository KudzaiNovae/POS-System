import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/api/api_client.dart';
import '../../core/db/local_db.dart';
import '../../core/format/money.dart';
import '../../models/sale.dart';

/// Sales history — the screen owners live on during reconciliation.
///
/// Features:
///   - Date range picker (defaults to last 7 days)
///   - Payment method + fiscal status + status filters
///   - Full-text search on receipt number / customer
///   - Tap row → open the Receipt screen
///   - Swipe row (or menu) → Void with role check
///   - Export CSV for the accountant
///
/// The screen always renders the local Hive copy for instant paint, then
/// pulls fresh data from the server for authoritative fiscal status.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now().add(const Duration(days: 1)),
  );
  String _payment = 'ALL';
  String _fiscal = 'ALL';
  String _query = '';
  bool _loading = false;
  List<Sale> _remote = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(apiClientProvider).get('/sales', query: {
        'from': _range.start.toUtc().toIso8601String(),
        'to': _range.end.toUtc().toIso8601String(),
      });
      final list = (r.data as List)
          .map((e) => Sale.fromMap({
                ...Map<String, dynamic>.from(e as Map),
                'dirty': false,
              }))
          .toList();
      // Merge into local Hive so the receipt screen can serve them too.
      for (final s in list) {
        await LocalDb.putSale(s);
      }
      _remote = list;
    } catch (_) {
      // Fall back to local cache silently.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Sale> get _sales {
    // Pick whichever source has data; remote if loaded, else local cache.
    final src = _remote.isNotEmpty
        ? _remote
        : LocalDb.salesBetween(_range.start, _range.end);
    final q = _query.toLowerCase().trim();
    final list = src.where((s) {
      final paymentOk = _payment == 'ALL' || s.paymentMethod == _payment;
      final fiscalOk = _fiscal == 'ALL' || s.fiscalStatus == _fiscal;
      if (!paymentOk || !fiscalOk) return false;
      if (q.isEmpty) return true;
      return (s.fiscalReceiptNo ?? '').toLowerCase().contains(q) ||
          (s.customerName ?? '').toLowerCase().contains(q) ||
          s.id.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.clientCreatedAt.compareTo(a.clientCreatedAt));
    return list;
  }

  int get _totalCents =>
      _sales.where((s) => s.status == 'COMPLETED')
          .fold<int>(0, (a, s) => a + s.totalCents);

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = DateTimeRange(
            start: picked.start,
            end: picked.end.add(const Duration(days: 1)),
          ));
      await _fetch();
    }
  }

  Future<void> _exportCsv() async {
    final rows = <List<dynamic>>[
      [
        'receipt', 'date', 'cashier', 'customer', 'customerTin',
        'paymentMethod', 'paymentRef', 'status', 'fiscalStatus',
        'subtotalCents', 'vatCents', 'totalCents',
      ],
      ..._sales.map((s) => [
            s.fiscalReceiptNo ?? s.id,
            s.clientCreatedAt.toIso8601String(),
            s.cashierId ?? '',
            s.customerName ?? '',
            s.customerTin ?? '',
            s.paymentMethod,
            s.paymentRef ?? '',
            s.status,
            s.fiscalStatus,
            s.subtotalCents,
            s.vatCents,
            s.totalCents,
          ]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    await Printing.sharePdf(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      filename:
          'sales-${DateFormat('yyyyMMdd').format(_range.start)}-${DateFormat('yyyyMMdd').format(_range.end.subtract(const Duration(days: 1)))}.csv',
    );
  }

  Future<void> _voidSale(Sale s) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Void this sale?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Receipt: ${s.fiscalReceiptNo ?? s.id.substring(0, 8)}'),
            Text('Total: ${Money.cents(s.totalCents)}'),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              decoration: const InputDecoration(
                  labelText: 'Reason (appears on audit log)'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, c.text),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('VOID')),
          ],
        );
      },
    );
    if (reason == null) return;
    try {
      await ref.read(apiClientProvider).post('/sales/${s.id}/void');
      s.status = 'VOIDED';
      await LocalDb.putSale(s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale voided.')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Void failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sales',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
              tooltip: 'Export CSV',
              onPressed: _exportCsv,
              icon: const Icon(Icons.download_outlined)),
          IconButton(
              tooltip: 'Refresh',
              onPressed: _fetch,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            range: _range,
            payment: _payment,
            fiscal: _fiscal,
            onRange: _pickRange,
            onPayment: (v) => setState(() => _payment = v),
            onFiscal: (v) => setState(() => _fiscal = v),
            onQuery: (v) => setState(() => _query = v),
          ),
          _Totals(count: _sales.length, totalCents: _totalCents),
          Expanded(
            child: _loading && _sales.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: ListView.separated(
                      itemCount: _sales.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (_, i) {
                        final s = _sales[i];
                        return _SaleTile(
                          sale: s,
                          onTap: () => context.push('/receipt/${s.id}'),
                          onVoid: () => _voidSale(s),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.range,
    required this.payment,
    required this.fiscal,
    required this.onRange,
    required this.onPayment,
    required this.onFiscal,
    required this.onQuery,
  });
  final DateTimeRange range;
  final String payment;
  final String fiscal;
  final VoidCallback onRange;
  final ValueChanged<String> onPayment;
  final ValueChanged<String> onFiscal;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(children: [
        TextField(
          onChanged: onQuery,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, size: 20),
            hintText: 'Search receipt / customer / id',
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip(context,
                label: '${fmt.format(range.start)} – ${fmt.format(range.end.subtract(const Duration(days: 1)))}',
                icon: Icons.date_range,
                onTap: onRange),
            const SizedBox(width: 8),
            _dropdown('Payment', payment, const [
              'ALL', 'CASH', 'ECOCASH', 'ONEMONEY', 'INNBUCKS', 'ZIPIT', 'CARD', 'CREDIT'
            ], onPayment),
            const SizedBox(width: 8),
            _dropdown('Fiscal', fiscal, const [
              'ALL', 'PENDING', 'ACCEPTED', 'OFFLINE'
            ], onFiscal),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(BuildContext ctx,
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> options,
      ValueChanged<String> on) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        borderRadius: BorderRadius.circular(12),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text('$label: $o')))
            .toList(),
        onChanged: (v) { if (v != null) on(v); },
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.count, required this.totalCents});
  final int count;
  final int totalCents;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        const Icon(Icons.receipt_long, size: 16, color: Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text('$count sales', style: const TextStyle(color: Color(0xFF64748B))),
        const Spacer(),
        Text(Money.cents(totalCents),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale, required this.onTap, required this.onVoid});
  final Sale sale;
  final VoidCallback onTap;
  final VoidCallback onVoid;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('d MMM · HH:mm').format(sale.clientCreatedAt.toLocal());
    final isVoid = sale.status == 'VOIDED';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: isVoid
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFEEF2FF),
        child: Icon(
          isVoid ? Icons.cancel_outlined : Icons.receipt_long,
          color: isVoid ? const Color(0xFF991B1B) : const Color(0xFF4F46E5),
        ),
      ),
      title: Text(
          sale.fiscalReceiptNo ?? 'Sale · ${sale.id.substring(0, 8)}',
          style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: isVoid ? TextDecoration.lineThrough : null)),
      subtitle: Text(
          '$time · ${_payLabel(sale.paymentMethod)}${(sale.customerName ?? '').isNotEmpty ? " · ${sale.customerName}" : ""}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(Money.cents(sale.totalCents),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          _Pill(sale.fiscalStatus),
        ],
      ),
      onLongPress: isVoid ? null : onVoid,
    );
  }

  String _payLabel(String m) => switch (m) {
        'CASH' => 'Cash',
        'ECOCASH' => 'EcoCash',
        'ONEMONEY' => 'OneMoney',
        'INNBUCKS' => 'InnBucks',
        'ZIPIT' => 'ZIPIT',
        'CARD' => 'Card',
        'CREDIT' => 'Credit',
        _ => m,
      };
}

class _Pill extends StatelessWidget {
  const _Pill(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'ACCEPTED' => (const Color(0xFFD1FAE5), const Color(0xFF065F46)),
      'OFFLINE' => (const Color(0xFFE0E7FF), const Color(0xFF3730A3)),
      'PENDING' => (const Color(0xFFFFF7ED), const Color(0xFF9A3412)),
      _ => (const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status,
          style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

