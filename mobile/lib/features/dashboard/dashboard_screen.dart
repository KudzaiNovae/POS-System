import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/db/local_db.dart';
import '../../core/format/money.dart';
import '../../core/sync/sync_service.dart';
import '../../models/product.dart';
import '../../models/sale.dart';

enum _Range { today, sevenDays, thirtyDays }

extension on _Range {
  String get label => switch (this) {
        _Range.today => 'Today',
        _Range.sevenDays => '7 days',
        _Range.thirtyDays => '30 days',
      };

  /// Start timestamp (inclusive) in local time.
  DateTime startFrom(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      _Range.today => today,
      _Range.sevenDays => today.subtract(const Duration(days: 6)),
      _Range.thirtyDays => today.subtract(const Duration(days: 29)),
    };
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  _Range _range = _Range.today;

  Future<void> _refresh() async {
    await ref.read(syncServiceProvider).syncNow();
    if (mounted) setState(() {});
  }

  _Metrics _compute() {
    final now = DateTime.now();
    final from = _range.startFrom(now);
    final sales = LocalDb.salesBetween(
      from.subtract(const Duration(seconds: 1)),
      now.add(const Duration(seconds: 1)),
    ).where((s) => s.status == 'COMPLETED').toList();

    final duration = now.difference(from);
    final previousFrom = from.subtract(duration);
    final previousSales = LocalDb.salesBetween(
      previousFrom.subtract(const Duration(seconds: 1)),
      from.add(const Duration(seconds: 1)),
    ).where((s) => s.status == 'COMPLETED').toList();

    final products = LocalDb.allProducts();
    return _Metrics.from(sales: sales, previousSales: previousSales, products: products, range: _range, from: from);
  }

  @override
  Widget build(BuildContext context) {
    final m = _compute();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            // --- range selector ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: _Range.values.map((r) {
                  final selected = _range == r;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _range = r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF4F46E5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          r.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                            color: selected ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ).animate().fadeIn().slideY(begin: -0.1),
            const SizedBox(height: 20),

            // --- KPI cards ---
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    label: 'Revenue',
                    value: Money.cents(m.revenueCents),
                    icon: Icons.payments_outlined,
                    isPrimary: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    label: 'Sales',
                    value: NumberFormat.decimalPattern().format(m.salesCount),
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    label: 'Avg ticket',
                    value: Money.cents(m.avgTicketCents),
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    label: 'Items sold',
                    value: _Metrics.nfmt(m.itemsSold),
                    icon: Icons.shopping_basket_outlined,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
            const SizedBox(height: 24),

            // --- revenue chart ---
            _SectionCard(
              title: 'Revenue Trend & Forecast',
              child: SizedBox(
                height: 220,
                child: _RevenueChart(spots: m.revenueOverTime, forecastSpots: m.forecastSpots, range: _range),
              ),
            ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),
            const SizedBox(height: 16),

            // --- peak hours ---
            _SectionCard(
              title: 'Peak Sales Hours',
              child: SizedBox(
                height: 160,
                child: _PeakHoursChart(hours: m.peakHours),
              ),
            ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.1),
            const SizedBox(height: 16),

            // --- payment breakdown ---
            _SectionCard(
              title: 'Payment Methods',
              child: m.paymentBreakdown.isEmpty
                  ? const _Placeholder(text: 'No sales yet.', icon: Icons.pie_chart_outline)
                  : SizedBox(
                      height: 200,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: _PaymentPieChart(data: m.paymentBreakdown, total: m.revenueCents),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 6,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: m.paymentBreakdown.entries.take(4).map((e) {
                                final pct = m.revenueCents == 0 ? 0.0 : e.value / m.revenueCents;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: _BarRow(
                                    label: _paymentLabel(e.key),
                                    value: Money.cents(e.value),
                                    fraction: pct,
                                    color: _paymentColor(e.key),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
            const SizedBox(height: 16),

            // --- top products ---
            _SectionCard(
              title: 'Trending Products',
              child: m.topProducts.isEmpty
                  ? const _Placeholder(
                      text: 'No products sold in this range.',
                      icon: Icons.bar_chart)
                  : Column(
                      children: [
                        for (final row in m.topProducts)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                      const SizedBox(height: 4),
                                      Text('${_Metrics.nfmt(row.qty)} sold', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      Money.cents(row.revenueCents),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    _TrendBadge(trend: row.trend),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 16),

            // --- low stock ---
            _SectionCard(
              title: 'Low stock',
              trailingBadge: m.lowStock.isEmpty ? null : m.lowStock.length,
              child: m.lowStock.isEmpty
                  ? const _Placeholder(
                      text: 'All stock levels are healthy.',
                      icon: Icons.check_circle_outline)
                  : Column(
                      children: [
                        for (final p in m.lowStock.take(8))
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    '${_Metrics.nfmt(p.stockQty)} ${p.unit}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (m.lowStock.length > 8)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '+${m.lowStock.length - 8} more products low on stock',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
            const SizedBox(height: 24),
            _SyncFootnote(),
          ],
        ),
      ),
    );
  }

  static String _paymentLabel(String key) => switch (key) {
        'CASH' => 'Cash',
        'ECOCASH' => 'EcoCash',
        'ONEMONEY' => 'OneMoney',
        'INNBUCKS' => 'InnBucks',
        'ZIPIT' => 'ZIPIT',
        'CARD' => 'Card',
        'CREDIT' => 'On account',
        // legacy / cross-border methods kept for backwards compatibility
        'MPESA' => 'M-Pesa',
        'MOMO' => 'MTN MoMo',
        _ => key,
      };

  static Color _paymentColor(String key) => switch (key) {
        'ECOCASH' => const Color(0xFF10B981), // Emerald
        'CASH' => const Color(0xFFF59E0B), // Amber
        'ONEMONEY' => const Color(0xFFEF4444), // Red
        'INNBUCKS' => const Color(0xFF0EA5E9), // Sky
        'CARD' => const Color(0xFF8B5CF6), // Violet
        'ZIPIT' => const Color(0xFF6366F1), // Indigo
        _ => const Color(0xFF94A3B8), // Slate
      };
}

// ===========================================================================
// Widgets
// ===========================================================================

class _TrendBadge extends StatelessWidget {
  final double trend;
  const _TrendBadge({required this.trend});
  
  @override
  Widget build(BuildContext context) {
    final isUp = trend >= 0;
    final trendColor = isUp ? Colors.green.shade700 : Colors.red.shade700;
    final trendBg = isUp ? Colors.green.shade50 : Colors.red.shade50;
    final icon = isUp ? Icons.trending_up : Icons.trending_down;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: trendBg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: trendColor),
          const SizedBox(width: 4),
          Text('${(trend.abs() * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: trendColor)),
        ],
      ),
    );
  }
}

class _PeakHoursChart extends StatelessWidget {
  final List<double> hours;
  const _PeakHoursChart({required this.hours});

  @override
  Widget build(BuildContext context) {
    if (hours.every((h) => h == 0)) return const _Placeholder(text: 'No data', icon: Icons.access_time);
    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                if (value % 4 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${value.toInt()}:00', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(24, (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: hours[i],
              color: const Color(0xFF6366F1),
              width: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        )),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<FlSpot> spots;
  final List<FlSpot> forecastSpots;
  final _Range range;

  const _RevenueChart({required this.spots, required this.forecastSpots, required this.range});

  @override
  Widget build(BuildContext context) {
    final allSpots = [...spots, ...forecastSpots];
    if (allSpots.isEmpty || allSpots.every((s) => s.y == 0)) {
      return const _Placeholder(text: 'No revenue data', icon: Icons.show_chart);
    }
    
    final maxY = allSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final roundedMaxY = (maxY * 1.2).ceilToDouble(); // Add 20% padding

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: roundedMaxY / 4 == 0 ? 1 : roundedMaxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                if (value == roundedMaxY || value == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(NumberFormat.compact().format(value), 
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: range == _Range.today ? 6 : (range == _Range.sevenDays ? 1 : 7),
              getTitlesWidget: (value, meta) {
                String text;
                if (range == _Range.today) {
                  int h = value.toInt() % 24;
                  text = '$h:00';
                } else if (range == _Range.sevenDays) {
                  final offset = value.toInt() - 6;
                  final d = DateTime.now().add(Duration(days: offset));
                  text = DateFormat('E').format(d);
                } else {
                  if (value % 7 != 0) return const SizedBox.shrink();
                  final offset = value.toInt() - 29;
                  final d = DateTime.now().add(Duration(days: offset));
                  text = DateFormat('MMM d').format(d);
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(text, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF4F46E5), // Indigo
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4F46E5).withOpacity(0.2),
                  const Color(0xFF4F46E5).withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          if (forecastSpots.isNotEmpty)
            LineChartBarData(
              spots: forecastSpots,
              isCurved: true,
              color: const Color(0xFF10B981), // Emerald
              barWidth: 3,
              isStrokeCapRound: true,
              dashArray: [5, 5],
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
        ],
      ),
    );
  }
}

class _PaymentPieChart extends StatelessWidget {
  final Map<String, int> data;
  final int total;

  const _PaymentPieChart({required this.data, required this.total});

  @override
  Widget build(BuildContext context) {
    if (total == 0 || data.isEmpty) return const SizedBox.shrink();

    final sections = data.entries.map((e) {
      final val = e.value.toDouble();
      return PieChartSectionData(
        color: _DashboardScreenState._paymentColor(e.key),
        value: val,
        title: '${(val / total * 100).round()}%',
        radius: 40,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(enabled: false),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        sections: sections,
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(
      {required this.label, required this.value, required this.icon, this.isPrimary = false});
  final String label;
  final String value;
  final IconData icon;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary ? null : Colors.white,
        gradient: isPrimary
            ? const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: isPrimary ? null : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isPrimary ? const Color(0xFF4F46E5).withOpacity(0.3) : Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isPrimary ? Colors.white.withOpacity(0.2) : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: isPrimary ? Colors.white : const Color(0xFF4F46E5)),
                ),
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        color: isPrimary ? Colors.white.withOpacity(0.9) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            Text(value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isPrimary ? Colors.white : const Color(0xFF1E293B),
                )),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.title, required this.child, this.trailingBadge});
  final String title;
  final Widget child;
  final int? trailingBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                if (trailingBadge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$trailingBadge',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow(
      {required this.label, required this.value, required this.fraction, required this.color});
  final String label;
  final String value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = fraction.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569), fontSize: 13))),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B), fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              height: 6,
              width: MediaQuery.of(context).size.width * 0.4 * clamped,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.text, required this.icon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF94A3B8), size: 32),
          ),
          const SizedBox(height: 16),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

class _SyncFootnote extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final last = LocalDb.lastPullAt;
    final isEpoch = last.year < 2000;
    final pending = LocalDb.outboxBox.length;
    final text = isEpoch
        ? 'Not synced yet'
        : 'Last sync ${DateFormat.Hm().format(last.toLocal())} · '
            '${DateFormat.yMMMd().format(last.toLocal())}';
    return Center(
      child: Column(
        children: [
          Text(text,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          if (pending > 0)
            Text('$pending change(s) waiting to sync',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

// ===========================================================================
// Metrics computation
// ===========================================================================

class _TopProductRow {
  _TopProductRow(this.productId, this.name, this.qty, this.revenueCents, this.previousQty);
  final String productId;
  final String name;
  num qty;
  int revenueCents;
  num previousQty;

  double get trend => previousQty == 0 ? 1.0 : (qty - previousQty) / previousQty;
}

class _Metrics {
  _Metrics({
    required this.revenueCents,
    required this.salesCount,
    required this.avgTicketCents,
    required this.itemsSold,
    required this.paymentBreakdown,
    required this.topProducts,
    required this.lowStock,
    required this.revenueOverTime,
    required this.forecastSpots,
    required this.forecastGrowthPct,
    required this.peakHours,
  });

  final int revenueCents;
  final int salesCount;
  final int avgTicketCents;
  final num itemsSold;
  final Map<String, int> paymentBreakdown;
  final List<_TopProductRow> topProducts;
  final List<Product> lowStock;
  final List<FlSpot> revenueOverTime;
  final List<FlSpot> forecastSpots;
  final double forecastGrowthPct;
  final List<double> peakHours;

  factory _Metrics.from({
    required List<Sale> sales,
    required List<Sale> previousSales,
    required List<Product> products,
    required _Range range,
    required DateTime from,
  }) {
    var revenue = 0;
    num items = 0;
    final byPayment = <String, int>{};
    final byProduct = <String, _TopProductRow>{};
    
    final revenueOverTime = <FlSpot>[];
    if (range == _Range.today) {
      final hours = List.filled(24, 0.0);
      for (final s in sales) {
        hours[s.clientCreatedAt.toLocal().hour] += (s.totalCents / 100.0);
      }
      for (var i = 0; i < 24; i++) {
        revenueOverTime.add(FlSpot(i.toDouble(), hours[i]));
      }
    } else {
      final days = range == _Range.sevenDays ? 7 : 30;
      final daily = List.filled(days, 0.0);
      for (final s in sales) {
        final diff = s.clientCreatedAt.toLocal().difference(from).inDays;
        if (diff >= 0 && diff < days) {
          daily[diff] += (s.totalCents / 100.0);
        }
      }
      for (var i = 0; i < days; i++) {
        revenueOverTime.add(FlSpot(i.toDouble(), daily[i]));
      }
    }

    final previousByProduct = <String, num>{};
    for (final s in previousSales) {
      for (final line in s.items) {
        previousByProduct[line.productId] = (previousByProduct[line.productId] ?? 0) + line.qty;
      }
    }

    final peakHours = List.filled(24, 0.0);
    for (final s in sales) {
      peakHours[s.clientCreatedAt.toLocal().hour] += (s.totalCents / 100.0);
    }

    for (final s in sales) {
      revenue += s.totalCents;
      byPayment.update(s.paymentMethod, (v) => v + s.totalCents,
          ifAbsent: () => s.totalCents);
      for (final line in s.items) {
        items += line.qty;
        final row = byProduct[line.productId] ??
            _TopProductRow(
                line.productId, line.nameSnapshot, 0, 0, previousByProduct[line.productId] ?? 0);
        row.qty += line.qty;
        row.revenueCents += line.lineTotalCents;
        byProduct[line.productId] = row;
      }
    }

    List<FlSpot> forecastSpots = [];
    double forecastGrowthPct = 0.0;
    
    if (revenueOverTime.length >= 2) {
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      int n = revenueOverTime.length;
      for (final p in revenueOverTime) {
        sumX += p.x;
        sumY += p.y;
        sumXY += p.x * p.y;
        sumX2 += p.x * p.x;
      }
      double denominator = (n * sumX2 - sumX * sumX);
      if (denominator != 0) {
        double slope = (n * sumXY - sumX * sumY) / denominator;
        double intercept = (sumY - slope * sumX) / n;
        
        double lastX = revenueOverTime.last.x;
        double lastY = slope * lastX + intercept;
        double predictedNextY = slope * (lastX + 1) + intercept;
        
        if (lastY != 0) {
           forecastGrowthPct = (predictedNextY - lastY) / lastY;
        }
        
        for (int i = 1; i <= 7; i++) {
          double x = lastX + i;
          double y = slope * x + intercept;
          forecastSpots.add(FlSpot(x, y < 0 ? 0 : y));
        }
      }
    }

    final top = byProduct.values.toList()
      ..sort((a, b) => b.revenueCents.compareTo(a.revenueCents));

    final low = products
        .where((p) => p.reorderLevel > 0 && p.stockQty <= p.reorderLevel)
        .toList()
      ..sort((a, b) => a.stockQty.compareTo(b.stockQty));

    final avg = sales.isEmpty ? 0 : (revenue / sales.length).round();

    // Sort payments by value desc for a predictable stack.
    final sortedPayments = Map.fromEntries(
      byPayment.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );

    return _Metrics(
      revenueCents: revenue,
      salesCount: sales.length,
      avgTicketCents: avg,
      itemsSold: items,
      paymentBreakdown: sortedPayments,
      topProducts: top.take(5).toList(),
      lowStock: low,
      revenueOverTime: revenueOverTime,
      forecastSpots: forecastSpots,
      forecastGrowthPct: forecastGrowthPct,
      peakHours: peakHours,
    );
  }

  static String nfmt(num n) {
    if (n is int || n == n.truncate()) {
      return NumberFormat.decimalPattern().format(n.toInt());
    }
    return n.toStringAsFixed(2);
  }
}
