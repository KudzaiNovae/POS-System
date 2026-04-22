import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';

/// FDMS (Fiscal Data Management System) audit screen.
///
/// Read-only view of every fiscalisation attempt the backend has
/// queued for ZIMRA. Owners/managers use this to debug rejections
/// and confirm the submitter is making progress.
class FdmsScreen extends ConsumerStatefulWidget {
  const FdmsScreen({super.key});

  @override
  ConsumerState<FdmsScreen> createState() => _FdmsScreenState();
}

class _FdmsScreenState extends ConsumerState<FdmsScreen> {
  String _filter = 'ALL';
  Future<_FdmsBundle>? _future;

  static const _statuses = ['ALL', 'PENDING', 'SUBMITTED', 'ACCEPTED', 'REJECTED'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = ref.read(apiClientProvider);
    final query = _filter == 'ALL' ? null : {'status': _filter};
    _future = Future.wait([
      api.get('/fiscal/submissions', query: query),
      api.get('/fiscal/submissions/summary'),
    ]).then((rs) {
      final list = (rs[0].data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final summary = Map<String, dynamic>.from(rs[1].data as Map);
      return _FdmsBundle(rows: list, summary: summary);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Fiscal queue (ZIMRA)',
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
        child: FutureBuilder<_FdmsBundle>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ErrorBox(
                      msg: 'Could not load fiscal queue.',
                      onRetry: _load),
                ],
              );
            }
            final bundle = snap.data ?? _FdmsBundle.empty();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _SummaryStrip(summary: bundle.summary),
                const SizedBox(height: 12),
                _FilterChips(
                  current: _filter,
                  options: _statuses,
                  onChange: (s) {
                    _filter = s;
                    _load();
                  },
                ),
                const SizedBox(height: 12),
                if (bundle.rows.isEmpty)
                  _Empty(filter: _filter)
                else
                  for (final row in bundle.rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SubmissionTile(row: row),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FdmsBundle {
  _FdmsBundle({required this.rows, required this.summary});
  factory _FdmsBundle.empty() => _FdmsBundle(rows: const [], summary: const {});
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> summary;
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    int v(String k) => (summary[k] as num?)?.toInt() ?? 0;
    final entries = [
      ('Pending', v('PENDING'), AppColors.warning),
      ('Submitted', v('SUBMITTED'), AppColors.info),
      ('Accepted', v('ACCEPTED'), AppColors.success),
      ('Rejected', v('REJECTED'), AppColors.error),
    ];
    return Row(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: entries[i].$3,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(entries[i].$2.toString(),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(entries[i].$1,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ),
          ),
          if (i != entries.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.current,
    required this.options,
    required this.onChange,
  });
  final String current;
  final List<String> options;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final o in options) ...[
            ChoiceChip(
              label: Text(_pretty(o)),
              selected: o == current,
              onSelected: (_) => onChange(o),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: o == current ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              side: BorderSide(
                color:
                    o == current ? AppColors.primary : AppColors.border,
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  String _pretty(String s) =>
      s == 'ALL' ? 'All' : s[0] + s.substring(1).toLowerCase();
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({required this.row});
  final Map<String, dynamic> row;

  Color _statusColor(String s) => switch (s.toUpperCase()) {
        'ACCEPTED' => AppColors.success,
        'REJECTED' => AppColors.error,
        'SUBMITTED' => AppColors.info,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'PENDING';
    final saleId = row['saleId']?.toString() ?? '—';
    final attempts = (row['attempts'] as num?)?.toInt() ?? 0;
    final lastError = row['lastError']?.toString();
    final createdAt = row['createdAt']?.toString();
    final next = row['nextAttemptAt']?.toString();
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
              const SizedBox(width: 8),
              Text('Attempts: $attempts',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
              const Spacer(),
              if (createdAt != null)
                Text(_pretty(createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Sale ${_short(saleId)}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          if (next != null && next != 'null') ...[
            const SizedBox(height: 4),
            Text('Next attempt ${_pretty(next)}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textTertiary)),
          ],
          if (lastError != null && lastError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(lastError,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.error)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _short(String s) =>
      s.length <= 8 ? s : '${s.substring(0, 4)}…${s.substring(s.length - 4)}';

  String _pretty(String s) {
    try {
      final dt = DateTime.parse(s).toLocal();
      return DateFormat('d MMM HH:mm').format(dt);
    } catch (_) {
      return s;
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filter});
  final String filter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined,
              color: AppColors.slate300, size: 48),
          const SizedBox(height: 8),
          Text(
            filter == 'ALL'
                ? 'No fiscal submissions yet.'
                : 'No $filter submissions.',
            style:
                const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
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
