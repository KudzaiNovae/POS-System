import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/format/money.dart';
import '../../models/invoice.dart';
import 'invoice_controller.dart';

/// Invoices list — the home screen of the invoice module.
///
/// We show every invoice, grouped visually by status so owners can see at a
/// glance what's outstanding. Filters let them slice by kind (Invoice / Quote
/// / Pro-forma / Credit note) and by status. A search box covers customer,
/// number, or notes. Tap → edit; FAB → new draft.
///
/// This is deliberately dense: SMEs on small screens want to see many rows at
/// once, so we use 2-line list tiles with a big trailing amount.
class InvoicesListScreen extends ConsumerStatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  ConsumerState<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends ConsumerState<InvoicesListScreen> {
  String _kind = 'ALL';
  String _status = 'ALL';
  String _query = '';

  static const _kinds = ['ALL', 'INVOICE', 'QUOTE', 'PROFORMA', 'CREDIT_NOTE'];
  static const _statuses = [
    'ALL',
    'DRAFT',
    'SENT',
    'PARTIAL',
    'PAID',
    'OVERDUE',
    'VOIDED',
  ];

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoiceListProvider);
    final filtered = _apply(invoices);

    // Headline totals for the filtered slice — help owners see receivables.
    final outstanding = filtered
        .where((i) => i.status == 'SENT' || i.status == 'PARTIAL' || i.status == 'OVERDUE')
        .fold<int>(0, (a, i) => a + i.balanceCents);
    final overdue = filtered
        .where((i) => i.status == 'OVERDUE')
        .fold<int>(0, (a, i) => a + i.balanceCents);

    return Scaffold(
      appBar: AppBar(
        title: Text('Invoices',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(invoiceListProvider.notifier).bootstrap(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/invoices/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
      ),
      body: Column(
        children: [
          _ReceivablesBanner(outstanding: outstanding, overdue: overdue),
          _FilterBar(
            kind: _kind,
            status: _status,
            onKind: (k) => setState(() => _kind = k),
            onStatus: (s) => setState(() => _status = s),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search customer, number, notes',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(onNew: () => context.push('/invoices/new'))
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.read(invoiceListProvider.notifier).bootstrap(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) => _InvoiceTile(inv: filtered[i])
                          .animate()
                          .fadeIn(
                              duration: 180.ms, delay: (i * 18).clamp(0, 300).ms)
                          .slideY(begin: 0.06),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Invoice> _apply(List<Invoice> src) {
    return src.where((i) {
      if (_kind != 'ALL' && i.kind != _kind) return false;
      if (_status != 'ALL' && i.status != _status) return false;
      if (_query.isNotEmpty) {
        final hay = [
          i.number ?? '',
          i.customerName ?? '',
          i.customerTin ?? '',
          i.notes ?? '',
          i.id,
        ].join(' ').toLowerCase();
        if (!hay.contains(_query)) return false;
      }
      return true;
    }).toList();
  }
}

class _ReceivablesBanner extends StatelessWidget {
  const _ReceivablesBanner({required this.outstanding, required this.overdue});
  final int outstanding;
  final int overdue;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Outstanding',
                    style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(Money.cents(outstanding),
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text('Overdue',
                        style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(Money.cents(overdue),
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.kind,
    required this.status,
    required this.onKind,
    required this.onStatus,
  });
  final String kind;
  final String status;
  final ValueChanged<String> onKind;
  final ValueChanged<String> onStatus;

  String _kindLabel(String k) => switch (k) {
        'ALL' => 'All kinds',
        'INVOICE' => 'Invoices',
        'QUOTE' => 'Quotes',
        'PROFORMA' => 'Pro-forma',
        'CREDIT_NOTE' => 'Credit notes',
        _ => k,
      };

  String _statusLabel(String s) => switch (s) {
        'ALL' => 'All',
        'DRAFT' => 'Draft',
        'SENT' => 'Sent',
        'PARTIAL' => 'Partial',
        'PAID' => 'Paid',
        'OVERDUE' => 'Overdue',
        'VOIDED' => 'Voided',
        _ => s,
      };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          for (final k in _InvoicesListScreenState._kinds)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(_kindLabel(k)),
                selected: kind == k,
                onSelected: (_) => onKind(k),
              ),
            ),
          Container(
              width: 1,
              height: 28,
              color: const Color(0xFFE2E8F0),
              margin: const EdgeInsets.symmetric(horizontal: 8)),
          for (final s in _InvoicesListScreenState._statuses)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(_statusLabel(s)),
                selected: status == s,
                onSelected: (_) => onStatus(s),
              ),
            ),
        ],
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.inv});
  final Invoice inv;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');
    final title = inv.number ?? 'Draft ${inv.id.substring(0, 6).toUpperCase()}';
    final customer = (inv.customerName?.isNotEmpty ?? false)
        ? inv.customerName!
        : 'Walk-in customer';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/invoices/edit/${inv.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _KindBadge(kind: inv.kind),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                              overflow: TextOverflow.ellipsis),
                        ),
                        _StatusPill(status: inv.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(customer,
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: const Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.event_outlined,
                            size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(df.format(inv.issueDate),
                            style: GoogleFonts.outfit(
                                fontSize: 11, color: Colors.grey.shade600)),
                        if (inv.dueDate != null) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.schedule_rounded,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text('due ${df.format(inv.dueDate!)}',
                              style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: inv.status == 'OVERDUE'
                                      ? Colors.redAccent
                                      : Colors.grey.shade600)),
                        ],
                        const Spacer(),
                        if (inv.dirty)
                          Tooltip(
                            message: 'Pending sync',
                            child: Icon(Icons.sync_problem_rounded,
                                size: 14, color: Colors.orange.shade400),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Money.cents(inv.totalCents),
                      style: GoogleFonts.outfit(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  if (inv.paidCents > 0 && inv.paidCents < inv.totalCents)
                    Text('${Money.cents(inv.balanceCents)} due',
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: Colors.orange.shade700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      'QUOTE' => (Icons.request_quote_outlined, const Color(0xFF0EA5E9)),
      'PROFORMA' => (Icons.description_outlined, const Color(0xFF8B5CF6)),
      'CREDIT_NOTE' => (Icons.undo_rounded, const Color(0xFFEF4444)),
      _ => (Icons.receipt_long_rounded, const Color(0xFF6366F1)),
    };
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  Color get _color => switch (status) {
        'PAID' => const Color(0xFF16A34A),
        'PARTIAL' => const Color(0xFFF59E0B),
        'OVERDUE' => const Color(0xFFEF4444),
        'VOIDED' => const Color(0xFF64748B),
        'SENT' => const Color(0xFF0EA5E9),
        'DRAFT' => const Color(0xFF94A3B8),
        _ => const Color(0xFF64748B),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: GoogleFonts.outfit(
              fontSize: 10, fontWeight: FontWeight.w700, color: _color)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No invoices yet',
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Create your first invoice or quote',
              style: GoogleFonts.outfit(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New invoice'),
          ),
        ],
      ),
    );
  }
}
