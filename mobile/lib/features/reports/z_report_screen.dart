import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';

/// Z-Reports — daily till close.
///
/// Owners/managers tap "Close today" to lock the day; the server
/// aggregates sales and returns a fully-formed report. Past reports
/// are listed below for audit and re-printing.
class ZReportScreen extends ConsumerStatefulWidget {
  const ZReportScreen({super.key});

  @override
  ConsumerState<ZReportScreen> createState() => _ZReportScreenState();
}

class _ZReportScreenState extends ConsumerState<ZReportScreen> {
  Future<List<Map<String, dynamic>>>? _future;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = ref.read(apiClientProvider);
    _future = api.get('/reports/z/list').then((r) =>
        (r.data as List).map((e) => Map<String, dynamic>.from(e)).toList());
    setState(() {});
  }

  Future<void> _closeToday() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Close today's till?"),
        content: const Text(
            'A Z-Report will be generated and sales for today will be locked. This cannot be reversed easily.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Close day')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _closing = true);
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.post('/reports/z/close', data: {});
      if (!mounted) return;
      _showReport(Map<String, dynamic>.from(r.data as Map));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not close — $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _closing = false);
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Z-Reports',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Close-day card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.calendar_today_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text("Today's till",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text(
                      'Closing the day generates a Z-Report and resets the till for tomorrow.',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _closing ? null : _closeToday,
                      icon: _closing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: AppColors.primaryDark,
                                  strokeWidth: 2))
                          : const Icon(Icons.lock_clock_rounded),
                      label: Text(_closing ? 'Closing…' : 'Close today'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Recent Z-Reports',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return _ErrorBox(
                    msg: 'Could not load reports.',
                    onRetry: _load,
                  );
                }
                final list = snap.data ?? const [];
                if (list.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        'No closed days yet.',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final r in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ReportTile(
                          report: r,
                          onTap: () => _showReport(r),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReport(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReportDetailSheet(report: r),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report, required this.onTap});
  final Map<String, dynamic> report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = report['businessDate']?.toString() ?? '';
    final count = (report['salesCount'] as num?)?.toInt() ?? 0;
    final gross = (report['grossCents'] as num?)?.toInt() ?? 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryVeryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: AppColors.primaryDark, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_prettyDate(date),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('$count sales',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
            ),
            Text(Money.cents(gross),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  String _prettyDate(String s) {
    try {
      return DateFormat('EEE d MMM yyyy').format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }
}

class _ReportDetailSheet extends StatelessWidget {
  const _ReportDetailSheet({required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final date = report['businessDate']?.toString() ?? '';
    final count = (report['salesCount'] as num?)?.toInt() ?? 0;
    final gross = (report['grossCents'] as num?)?.toInt() ?? 0;
    final net = (report['netCents'] as num?)?.toInt() ?? 0;
    final vat = (report['vatCents'] as num?)?.toInt() ?? 0;

    final byPayment = _decode(report['byPayment']);
    final byVat = _decode(report['byVatClass']);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Z-Report',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(_prettyDate(date),
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            _kv('Sales count', count.toString(), bold: true),
            _kv('Gross', Money.cents(gross), bold: true),
            _kv('Net', Money.cents(net)),
            _kv('VAT', Money.cents(vat),
                color: AppColors.warning),
            const Divider(height: 28),
            const Text('By payment',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (byPayment.isEmpty)
              const Text('—',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textTertiary))
            else
              for (final e in byPayment.entries)
                _kv(e.key, Money.cents(_intOf(e.value))),
            const Divider(height: 28),
            const Text('By VAT class',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (byVat.isEmpty)
              const Text('—',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textTertiary))
            else
              for (final e in byVat.entries)
                _kv(e.key, Money.cents(_intOf(e.value))),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary))),
          Text(v,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? AppColors.textPrimary,
              )),
        ],
      ),
    );
  }

  Map<String, dynamic> _decode(dynamic v) {
    if (v == null) return const {};
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String && v.isNotEmpty) {
      try {
        final m = jsonDecode(v);
        if (m is Map) return Map<String, dynamic>.from(m);
      } catch (_) {}
    }
    return const {};
  }

  int _intOf(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String _prettyDate(String s) {
    try {
      return DateFormat('EEEE, d MMMM yyyy').format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.msg, required this.onRetry});
  final String msg;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppColors.error, size: 28),
          const SizedBox(height: 8),
          Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          FilledButton.tonal(
              onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
