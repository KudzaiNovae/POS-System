import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/db/local_db.dart' show LocalDb;
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';

/// Server-driven analytics surface ("Insights" tab).
///
/// All numbers come from `GET /analytics/dashboard?days=N` so the BI
/// stays consistent with the back-office view. Premium widgets
/// (reorder predictions, basket co-purchase) auto-hide behind a
/// PRO upgrade card when the server signals `advancedAnalyticsLocked`.
///
/// We deliberately avoid client-side aggregation: the backend already
/// returns ready-to-render maps so we don't drift from accounting.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  /// Window selector — these match the validator on AnalyticsService (1..365).
  int _days = 30;
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = ref.read(apiClientProvider);
    _future = api
        .get('/analytics/dashboard', query: {'days': _days})
        .then((r) => Map<String, dynamic>.from(r.data as Map));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Insights',
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
            _WindowPicker(
              value: _days,
              onChanged: (d) {
                _days = d;
                _load();
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _LoadingSkeleton();
                }
                if (snap.hasError) {
                  return _ErrorBox(
                    message: 'Could not load insights. ${snap.error}',
                    onRetry: _load,
                  );
                }
                final data = snap.data ?? const {};
                return _DashboardBody(data: data);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Window picker
// ─────────────────────────────────────────────────────────────────────
class _WindowPicker extends StatelessWidget {
  const _WindowPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static const _options = [
    (label: '7 days', days: 7),
    (label: '30 days', days: 30),
    (label: '90 days', days: 90),
    (label: '365 days', days: 365),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: _options.map((o) {
          final selected = o.days == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.days),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  o.label,
                  style: TextStyle(
                    color:
                        selected ? Colors.white : AppColors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────
class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final headline = Map<String, dynamic>.from(data['headline'] ?? const {});
    final trend = (data['revenueTrend'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final paymentMix = (data['paymentMix'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final vatByClass = (data['vatByClass'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final topProducts = (data['topProducts'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final lowStock = (data['lowStock'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final hourHeatmap = (data['hourHeatmap'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final reorder = (data['reorderPredictions'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final basket = (data['basketCoPurchase'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final margin = Map<String, dynamic>.from(data['margin'] ?? const {});
    final locked = data['advancedAnalyticsLocked'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeadlineGrid(headline: headline),
        const SizedBox(height: 16),
        _MarginCard(margin: margin),
        const SizedBox(height: 16),
        _Card(
          title: 'Revenue trend',
          subtitle: 'Daily totals across the selected window',
          child: _RevenueTrend(points: trend),
        ),
        const SizedBox(height: 16),
        _Card(
          title: 'Payment mix',
          subtitle: 'Where the money came in',
          child: _PaymentMix(rows: paymentMix),
        ),
        const SizedBox(height: 16),
        _Card(
          title: 'VAT by class',
          subtitle: 'For ZIMRA returns',
          child: _VatByClass(rows: vatByClass),
        ),
        const SizedBox(height: 16),
        _Card(
          title: 'Top products',
          subtitle: 'Bestsellers by revenue',
          child: _TopProducts(rows: topProducts),
        ),
        const SizedBox(height: 16),
        _Card(
          title: 'Hour heatmap',
          subtitle: 'When customers buy (your local time)',
          child: _HourHeatmap(rows: hourHeatmap),
        ),
        const SizedBox(height: 16),
        _Card(
          title: 'Low stock',
          subtitle: 'Items at or below their reorder level',
          child: _LowStock(rows: lowStock),
        ),
        const SizedBox(height: 16),
        if (locked)
          const _UpgradeCard(
            title: 'Reorder predictions & basket insights',
            body:
                'Upgrade to PRO to unlock stock-out forecasts, basket co-purchase patterns and inventory health scores.',
          )
        else ...[
          _Card(
            title: 'Reorder predictions',
            subtitle: 'Days of cover at current sell-through',
            child: _Reorder(rows: reorder),
          ),
          const SizedBox(height: 16),
          _Card(
            title: 'Basket insights',
            subtitle: 'Frequently bought together',
            child: _Basket(rows: basket),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Reusable card scaffolding
// ─────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Headline KPI grid
// ─────────────────────────────────────────────────────────────────────
class _HeadlineGrid extends StatelessWidget {
  const _HeadlineGrid({required this.headline});
  final Map<String, dynamic> headline;

  int _int(String k) => (headline[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Kpi(
        label: 'Sales',
        value: NumberFormat.decimalPattern().format(_int('salesCount')),
        icon: Icons.receipt_long_rounded,
        color: AppColors.primary,
      ),
      _Kpi(
        label: 'Revenue',
        value: Money.cents(_int('revenueCents')),
        icon: Icons.payments_rounded,
        color: AppColors.success,
      ),
      _Kpi(
        label: 'Avg basket',
        value: Money.cents(_int('avgBasketCents')),
        icon: Icons.shopping_basket_rounded,
        color: AppColors.info,
      ),
      _Kpi(
        label: 'VAT collected',
        value: Money.cents(_int('vatCents')),
        icon: Icons.account_balance_rounded,
        color: AppColors.warning,
      ),
      _Kpi(
        label: 'Pending fiscal',
        value: NumberFormat.decimalPattern().format(_int('pendingFiscal')),
        icon: Icons.cloud_sync_rounded,
        color:
            _int('pendingFiscal') > 0 ? AppColors.error : AppColors.success,
      ),
      _Kpi(
        label: 'SKUs sold',
        value: NumberFormat.decimalPattern().format(_int('uniqueProductsSold')),
        icon: Icons.inventory_2_rounded,
        color: AppColors.primaryDark,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.0,
      children: tiles,
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Margin card
// ─────────────────────────────────────────────────────────────────────
class _MarginCard extends StatelessWidget {
  const _MarginCard({required this.margin});
  final Map<String, dynamic> margin;

  @override
  Widget build(BuildContext context) {
    final revenue = (margin['revenueCents'] as num?)?.toInt() ?? 0;
    final cogs = (margin['cogsCents'] as num?)?.toInt() ?? 0;
    final profit = (margin['grossProfitCents'] as num?)?.toInt() ?? 0;
    final pct = (margin['marginPct'] as num?)?.toDouble() ?? 0.0;
    final positive = profit >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: positive
              ? const [Color(0xFF10B981), Color(0xFF059669)]
              : const [Color(0xFFDC2626), Color(0xFF991B1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('Gross profit',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${pct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(Money.cents(profit),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Revenue ${Money.cents(revenue)}  •  COGS ${Money.cents(cogs)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Revenue trend (line chart)
// ─────────────────────────────────────────────────────────────────────
class _RevenueTrend extends StatelessWidget {
  const _RevenueTrend({required this.points});
  final List<Map<String, dynamic>> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _Empty(message: 'No sales in this period yet.');
    }

    final spots = <FlSpot>[];
    double maxY = 1;
    for (var i = 0; i < points.length; i++) {
      final cents = (points[i]['revenueCents'] as num?)?.toDouble() ?? 0;
      final y = cents / 100.0;
      spots.add(FlSpot(i.toDouble(), y));
      if (y > maxY) maxY = y;
    }

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY * 1.15,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 3,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 3]),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: maxY / 3,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _shortMoney(v),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textTertiary),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (points.length / 5).clamp(1, 9999).toDouble(),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  final s = points[i]['date']?.toString() ?? '';
                  // format yyyy-mm-dd → m/d
                  final parts = s.split('-');
                  final lbl =
                      parts.length == 3 ? '${parts[1]}/${parts[2]}' : s;
                  return Text(lbl,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textTertiary));
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (items) => items
                  .map((it) => LineTooltipItem(
                        Money.format(it.y),
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 2.5,
              color: AppColors.primary,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.25),
                    AppColors.primary.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact "$1.2k" / "$1.4M" labels for the y-axis.
  String _shortMoney(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Payment mix (donut + legend)
// ─────────────────────────────────────────────────────────────────────
class _PaymentMix extends StatelessWidget {
  const _PaymentMix({required this.rows});
  final List<Map<String, dynamic>> rows;

  static const _palette = [
    Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFF59E0B),
    Color(0xFFEF4444), Color(0xFF0EA5E9), Color(0xFF8B5CF6),
    Color(0xFFEC4899), Color(0xFF14B8A6),
  ];

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _Empty(message: 'No payments captured yet.');
    }
    final total = rows.fold<int>(
        0, (a, r) => a + ((r['revenueCents'] as num?)?.toInt() ?? 0));
    if (total == 0) {
      return const _Empty(message: 'No payments captured yet.');
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 38,
              sections: [
                for (var i = 0; i < rows.length; i++)
                  PieChartSectionData(
                    color: _palette[i % _palette.length],
                    value:
                        ((rows[i]['revenueCents'] as num?)?.toInt() ?? 0)
                            .toDouble(),
                    radius: 26,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                _legendRow(
                  color: _palette[i % _palette.length],
                  label: _humanMethod(rows[i]['method']?.toString() ?? '—'),
                  value: (rows[i]['revenueCents'] as num?)?.toInt() ?? 0,
                  total: total,
                ),
                if (i != rows.length - 1) const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendRow({
    required Color color,
    required String label,
    required int value,
    required int total,
  }) {
    final pct = total == 0 ? 0 : (value * 100 / total);
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500)),
        ),
        Text('${pct.toStringAsFixed(0)}%',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textTertiary)),
        const SizedBox(width: 8),
        Text(Money.cents(value),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }

  String _humanMethod(String s) => switch (s.toUpperCase()) {
        'CASH' => 'Cash',
        'CARD' => 'Card',
        'ECOCASH' => 'EcoCash',
        'ONEMONEY' => 'OneMoney',
        'INNBUCKS' => 'InnBucks',
        'ZIPIT' => 'ZIPIT',
        'CREDIT' => 'Credit',
        'BANK' => 'Bank transfer',
        'UNKNOWN' => 'Unknown',
        _ => s,
      };
}

// ─────────────────────────────────────────────────────────────────────
// VAT by class
// ─────────────────────────────────────────────────────────────────────
class _VatByClass extends StatelessWidget {
  const _VatByClass({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _Empty(message: 'No taxable sales yet.');
    }
    return Column(
      children: [
        const Row(
          children: [
            Expanded(flex: 3, child: _Th('Class')),
            Expanded(flex: 3, child: _Th('Net', align: TextAlign.right)),
            Expanded(flex: 3, child: _Th('VAT', align: TextAlign.right)),
            Expanded(flex: 3, child: _Th('Gross', align: TextAlign.right)),
          ],
        ),
        const Divider(height: 16, color: AppColors.divider),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(_classLabel(r['class']?.toString() ?? 'STANDARD'),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    Money.cents((r['netCents'] as num?)?.toInt() ?? 0),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    Money.cents((r['vatCents'] as num?)?.toInt() ?? 0),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.warning),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    Money.cents((r['grossCents'] as num?)?.toInt() ?? 0),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _classLabel(String c) => switch (c.toUpperCase()) {
        'STANDARD' => 'Standard 15%',
        'ZERO' => 'Zero-rated',
        'EXEMPT' => 'Exempt',
        'LUXURY' => 'Luxury',
        _ => c,
      };
}

class _Th extends StatelessWidget {
  const _Th(this.text, {this.align = TextAlign.left});
  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary),
      );
}

// ─────────────────────────────────────────────────────────────────────
// Top products
// ─────────────────────────────────────────────────────────────────────
class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _Empty(message: 'No sales recorded yet.');
    }
    final maxRev = rows
        .map((r) => (r['revenueCents'] as num?)?.toInt() ?? 0)
        .fold<int>(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _TopProductRow(
              rank: i + 1,
              name: rows[i]['name']?.toString() ?? '—',
              revenueCents: (rows[i]['revenueCents'] as num?)?.toInt() ?? 0,
              maxRev: maxRev,
            ),
          ),
      ],
    );
  }
}

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({
    required this.rank,
    required this.name,
    required this.revenueCents,
    required this.maxRev,
  });
  final int rank;
  final String name;
  final int revenueCents;
  final int maxRev;

  @override
  Widget build(BuildContext context) {
    final pct = maxRev == 0 ? 0.0 : revenueCents / maxRev;
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text('$rank.',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  Text(Money.cents(revenueCents),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct.clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: AppColors.slate100,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Hour heatmap
// ─────────────────────────────────────────────────────────────────────
class _HourHeatmap extends StatelessWidget {
  const _HourHeatmap({required this.rows});
  final List<Map<String, dynamic>> rows;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _Empty(message: 'Not enough data to draw a heatmap yet.');
    }

    // Build 7x24 matrix of revenue
    final grid = List.generate(7, (_) => List<int>.filled(24, 0));
    int max = 0;
    for (final r in rows) {
      final d = (r['dayIndex'] as num?)?.toInt() ?? 0;
      final h = (r['hour'] as num?)?.toInt() ?? 0;
      final c = (r['revenueCents'] as num?)?.toInt() ?? 0;
      if (d < 0 || d >= 7 || h < 0 || h >= 24) continue;
      grid[d][h] = c;
      if (c > max) max = c;
    }
    if (max == 0) {
      return const _Empty(message: 'Not enough data to draw a heatmap yet.');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hour header
          Row(
            children: [
              const SizedBox(width: 30),
              for (var h = 0; h < 24; h++)
                SizedBox(
                  width: 14,
                  child: Text(
                    h % 3 == 0 ? '$h' : '',
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var d = 0; d < 7; d++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(_days[d],
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600)),
                  ),
                  for (var h = 0; h < 24; h++)
                    Tooltip(
                      message:
                          '${_days[d]} ${h.toString().padLeft(2, '0')}:00 — ${Money.cents(grid[d][h])}',
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        width: 12,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.primary
                              .withOpacity(grid[d][h] == 0
                                  ? 0.04
                                  : 0.15 + (grid[d][h] / max) * 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Less',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textTertiary)),
              const SizedBox(width: 6),
              for (final a in [0.1, 0.3, 0.5, 0.7, 0.9])
                Container(
                  margin: const EdgeInsets.only(right: 2),
                  width: 12,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(a),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              const SizedBox(width: 4),
              const Text('More',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Low stock
// ─────────────────────────────────────────────────────────────────────
class _LowStock extends StatelessWidget {
  const _LowStock({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _Empty(message: 'Stock looks healthy 🎉');
    }
    return Column(
      children: [
        for (final r in rows.take(10))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(r['name']?.toString() ?? '—',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Text(
                  '${_num(r['stockQty'])} / ${_num(r['reorderLevel'])}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        if (rows.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton(
              onPressed: () => context.go('/products'),
              child: Text('See all ${rows.length} items'),
            ),
          ),
      ],
    );
  }

  String _num(dynamic v) {
    if (v == null) return '0';
    final n = v is num ? v : num.tryParse(v.toString()) ?? 0;
    return n == n.toInt() ? n.toInt().toString() : n.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Reorder predictions (PRO)
// ─────────────────────────────────────────────────────────────────────
class _Reorder extends StatelessWidget {
  const _Reorder({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _Empty(
          message:
              'No movement signals yet — run more sales for a forecast.');
    }
    return Column(
      children: [
        for (final r in rows.take(10))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  r['urgent'] == true
                      ? Icons.priority_high_rounded
                      : Icons.schedule_rounded,
                  color: r['urgent'] == true
                      ? AppColors.error
                      : AppColors.info,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['name']?.toString() ?? '—',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        '${_fmt(r['velocityPerDay'])}/day · stock ${_fmt(r['stockQty'])}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (r['urgent'] == true
                            ? AppColors.error
                            : AppColors.info)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_fmt(r['daysOfStock'])}d',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: r['urgent'] == true
                          ? AppColors.error
                          : AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    return n == n.toInt() ? n.toInt().toString() : n.toStringAsFixed(1);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Basket co-purchase (PRO)
// ─────────────────────────────────────────────────────────────────────
class _Basket extends StatelessWidget {
  const _Basket({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _Empty(
          message: 'Need more multi-item baskets to surface patterns.');
    }
    return Column(
      children: [
        for (final r in rows.take(8))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r['a']?.toString() ?? '—'}  +  ${r['b']?.toString() ?? '—'}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${r['baskets']} baskets · lift ×${r['lift']}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.link_rounded,
                    size: 16, color: AppColors.textTertiary),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Upgrade card (FREE tier)
// ─────────────────────────────────────────────────────────────────────
class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.arrow_upward_rounded, size: 16),
              label: Text(LocalDb.tier == 'FREE'
                  ? 'Upgrade plan'
                  : 'Manage subscription'),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Empty / loading / error helpers
// ─────────────────────────────────────────────────────────────────────
class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar({double h = 80}) => Container(
          height: h,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.slate100,
            borderRadius: BorderRadius.circular(12),
          ),
        );
    return Column(
      children: [
        bar(h: 90),
        bar(h: 90),
        bar(h: 200),
        bar(h: 160),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
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
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
