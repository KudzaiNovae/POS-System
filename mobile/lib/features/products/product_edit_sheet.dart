import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../models/product.dart';
import '../../core/db/local_db.dart';

/// Result returned from [ProductEditSheet]. Mutually exclusive: either the
/// caller receives an updated/created product, or the delete flag.
class ProductEditResult {
  ProductEditResult.save(this.product) : delete = false;
  ProductEditResult.remove()
      : product = null,
        delete = true;

  final Product? product;
  final bool delete;
}

class ProductEditSheet extends StatefulWidget {
  const ProductEditSheet({super.key, this.existing});
  final Product? existing;

  @override
  State<ProductEditSheet> createState() => _ProductEditSheetState();
}

class _ProductEditSheetState extends State<ProductEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _price;
  late final TextEditingController _cost;
  late final TextEditingController _stock;
  late final TextEditingController _reorder;
  late String _unit;

  static const _units = ['pc', 'kg', 'g', 'L', 'ml', 'pack', 'box'];

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _price = TextEditingController(
        text: p == null ? '' : (p.priceCents / 100).toStringAsFixed(2));
    _cost = TextEditingController(
        text: p == null ? '' : (p.costCents / 100).toStringAsFixed(2));
    _stock = TextEditingController(
        text: p == null ? '' : _trim(p.stockQty.toString()));
    _reorder = TextEditingController(
        text: p == null ? '' : _trim(p.reorderLevel.toString()));
    _unit = p?.unit ?? 'pc';
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _price.dispose();
    _cost.dispose();
    _stock.dispose();
    _reorder.dispose();
    super.dispose();
  }

  static String _trim(String s) {
    if (!s.contains('.')) return s;
    final trimmed = s.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1)
                                 : trimmed;
  }

  int _toCents(String raw) {
    final n = double.tryParse(raw.trim()) ?? 0;
    return (n * 100).round();
  }

  num _toNum(String raw) => num.tryParse(raw.trim()) ?? 0;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.existing;
    final updated = Product(
      id: existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      priceCents: _toCents(_price.text),
      costCents: _toCents(_cost.text),
      stockQty: _toNum(_stock.text),
      reorderLevel: _toNum(_reorder.text),
      unit: _unit,
      version: existing?.version ?? 1,
      deleted: false,
      updatedAt: DateTime.now().toUtc(),
      dirty: true,
    );
    Navigator.of(context).pop(ProductEditResult.save(updated));
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${widget.existing!.name}"?'),
        content: const Text(
            'This product will be hidden from the till. Past sales keep their history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(ProductEditResult.remove());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    // Modern input decoration style
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade600, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: Color(0xFF64748B)),
      floatingLabelStyle: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEdit ? 'Edit product' : 'New product',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  autofocus: !isEdit,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  decoration: inputDecoration.copyWith(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sku,
                        textCapitalization: TextCapitalization.characters,
                        decoration: inputDecoration.copyWith(labelText: 'SKU (optional)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _barcode,
                        keyboardType: TextInputType.number,
                        decoration: inputDecoration.copyWith(labelText: 'Barcode'),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                        decoration: inputDecoration.copyWith(
                          labelText: 'Price',
                          prefixText: '${LocalDb.currency} ',
                          prefixStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                        ),
                        inputFormatters: [_decimalFormatter],
                        validator: (v) => double.tryParse(v ?? '') == null
                            ? 'Enter a price'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cost,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: inputDecoration.copyWith(
                          labelText: 'Cost',
                          prefixText: '${LocalDb.currency} ',
                          prefixStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                        ),
                        inputFormatters: [_decimalFormatter],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _stock,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: inputDecoration.copyWith(labelText: 'Stock on hand'),
                        inputFormatters: [_decimalFormatter],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _reorder,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: inputDecoration.copyWith(labelText: 'Reorder at'),
                        inputFormatters: [_decimalFormatter],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _unit,
                        decoration: inputDecoration.copyWith(labelText: 'Unit', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16)),
                        icon: const Icon(Icons.expand_more, color: Color(0xFF64748B)),
                        items: _units
                            .map((u) => DropdownMenuItem(
                                value: u, child: Text(u, style: const TextStyle(fontWeight: FontWeight.w600))))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _unit = v ?? _unit),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    if (isEdit)
                      TextButton.icon(
                        onPressed: _confirmDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(isEdit ? 'Save' : 'Add', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Keep a private decimal-only formatter — allows '1', '1.', '1.5', rejects '1.5.5'.
final _decimalFormatter = TextInputFormatter.withFunction((oldV, newV) {
  final t = newV.text;
  if (t.isEmpty) return newV;
  if (RegExp(r'^\d*\.?\d*$').hasMatch(t)) return newV;
  return oldV;
});
