import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/db/local_db.dart';
import '../../core/format/money.dart';
import '../../core/subscription/feature_gate.dart';
import '../../core/sync/sync_service.dart';
import '../../models/product.dart';
import 'product_edit_sheet.dart';

enum _Sort { name, stockAsc, recent }

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  String _filter = '';
  _Sort _sort = _Sort.name;
  bool _onlyLowStock = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _visible() {
    var list = LocalDb.allProducts();
    if (_onlyLowStock) {
      list = list.where((p) => p.stockQty <= p.reorderLevel).toList();
    }
    if (_filter.isNotEmpty) {
      final f = _filter.toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(f) ||
              (p.sku?.toLowerCase().contains(f) ?? false) ||
              (p.barcode?.contains(_filter) ?? false))
          .toList();
    }
    switch (_sort) {
      case _Sort.name:
        list.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _Sort.stockAsc:
        list.sort((a, b) => a.stockQty.compareTo(b.stockQty));
        break;
      case _Sort.recent:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }
    return list;
  }

  Future<void> _openEditor({Product? existing}) async {
    if (existing == null &&
        !FeatureGate.canAddProduct(LocalDb.allProducts().length)) {
      _showTierLimitDialog();
      return;
    }
    final result = await showModalBottomSheet<ProductEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProductEditSheet(existing: existing),
    );
    if (result == null || !mounted) return;

    if (result.delete && existing != null) {
      existing.deleted = true;
      await ref.read(syncServiceProvider).enqueueProduct(existing);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${existing.name}"')),
      );
    } else if (result.product != null) {
      await ref.read(syncServiceProvider).enqueueProduct(result.product!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null
              ? 'Added "${result.product!.name}"'
              : 'Updated "${result.product!.name}"'),
        ),
      );
    }
    setState(() {});
  }

  void _showTierLimitDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Product limit reached'),
        content: Text(
          'Your ${LocalDb.tier} plan allows up to '
          '${FeatureGate.productLimit} products. Upgrade to add more.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Settings screen has the upgrade CTA.
              Navigator.of(context).maybePop();
            },
            child: const Text('See plans'),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    await ref.read(syncServiceProvider).syncNow();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final all = LocalDb.allProducts();
    final products = _visible();
    final limit = FeatureGate.productLimit;
    final overLimit = all.length >= limit;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: _refresh,
          ),
          PopupMenuButton<_Sort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Sort.name, child: Text('Sort: Name')),
              PopupMenuItem(
                  value: _Sort.stockAsc, child: Text('Sort: Stock (low first)')),
              PopupMenuItem(
                  value: _Sort.recent, child: Text('Sort: Recently updated')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                  suffixIcon: _filter.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _filter = '');
                          },
                        )
                      : null,
                  hintText: 'Search name, SKU, barcode',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
          ).animate().fadeIn().slideY(begin: -0.1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Low stock only'),
                  labelStyle: TextStyle(
                    fontWeight: _onlyLowStock ? FontWeight.bold : FontWeight.w500,
                    color: _onlyLowStock ? Colors.white : const Color(0xFF475569),
                  ),
                  backgroundColor: const Color(0xFFF1F5F9),
                  selectedColor: const Color(0xFF4F46E5),
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.transparent)),
                  selected: _onlyLowStock,
                  onSelected: (v) => setState(() => _onlyLowStock = v),
                ).animate().fadeIn(delay: 50.ms),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: overLimit ? Colors.red.shade50 : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${all.length} / ${limit >= (1 << 29) ? '∞' : limit}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: overLimit ? Colors.red.shade700 : const Color(0xFF4F46E5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ).animate().fadeIn(delay: 100.ms),
              ],
            ),
          ),
          if (overLimit)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You are at the ${LocalDb.tier} plan limit. '
                      'Upgrade to add more products.',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.red.shade800, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: products.isEmpty
                  ? _EmptyState(
                      hasAny: all.isNotEmpty,
                      onAdd: () => _openEditor(),
                    ).animate().fadeIn(delay: 200.ms)
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 96),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: products.length,
                      itemBuilder: (ctx, i) {
                        final p = products[i];
                        final lowStock = p.stockQty <= p.reorderLevel;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, Color(0xFFF8FAFC)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            onTap: () => _openEditor(existing: p),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE0E7FF)),
                              ),
                              child: Center(
                                child: Text(
                                  p.name.isNotEmpty ? p.name.substring(0, 1).toUpperCase() : 'P',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                ),
                              ),
                            ),
                            title: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1E293B)),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  if (p.sku != null && p.sku!.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                      child: Text(p.sku!,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (lowStock)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'LOW STOCK',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ).animate(onPlay: (controller) => controller.repeat(reverse: true)).fade(begin: 0.5, end: 1.0, duration: 800.ms),
                                  if (p.dirty) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.cloud_upload_outlined,
                                        size: 16,
                                        color: Color(0xFF94A3B8)),
                                  ],
                                ],
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(Money.cents(p.priceCents),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF4F46E5))),
                                const SizedBox(height: 6),
                                Text(
                                  '${_qtyString(p.stockQty)} ${p.unit}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: lowStock
                                        ? Colors.red.shade700
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: (50 * i.clamp(0, 10)).ms).slideX(begin: 0.1);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: overLimit ? _showTierLimitDialog : () => _openEditor(),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        icon: Icon(overLimit ? Icons.lock_outline : Icons.add),
        label: const Text('Add product', style: TextStyle(fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 300.ms, curve: Curves.easeOutBack).then(delay: 2.seconds).shake(duration: 500.ms, hz: 4, curve: Curves.easeInOut),
    );
  }

  static String _qtyString(num q) {
    if (q is int || q == q.truncate()) return q.toInt().toString();
    return q.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(
        RegExp(r'\.$'), '');
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAny, required this.onAdd});
  final bool hasAny;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final title =
        hasAny ? 'No matches' : 'No products yet';
    final msg = hasAny
        ? 'Try a different search or clear the Low-stock filter.'
        : 'Add your first product to get started.';
    return LayoutBuilder(
      builder: (ctx, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: c.maxHeight * 0.8,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      size: 72, color: Color(0xFF4F46E5)),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true)).moveY(begin: -8, end: 8, duration: 2.seconds, curve: Curves.easeInOut),
                const SizedBox(height: 24),
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 12),
                Text(msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF64748B))),
                const SizedBox(height: 32),
                if (!hasAny)
                  FilledButton.icon(
                    onPressed: onAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add your first product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

