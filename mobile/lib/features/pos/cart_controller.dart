import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/format/vat.dart';
import '../../models/product.dart';
import '../../models/sale.dart';

class CartLine {
  CartLine({required this.product, this.qty = 1});
  final Product product;
  num qty;
  int get lineTotalCents => (product.priceCents * qty).round();
}

class CartState {
  CartState({this.lines = const []});
  final List<CartLine> lines;

  int get totalCents => lines.fold(0, (a, l) => a + l.lineTotalCents);
  int get itemCount => lines.fold<int>(0, (a, l) => a + l.qty.toInt());
}

final cartControllerProvider =
    StateNotifierProvider<CartController, CartState>((ref) => CartController());

class CartController extends StateNotifier<CartState> {
  CartController() : super(CartState());
  final _uuid = const Uuid();

  void add(Product p) {
    final existing = state.lines
        .where((l) => l.product.id == p.id)
        .cast<CartLine?>()
        .firstOrNull;
    if (existing != null) {
      existing.qty += 1;
      state = CartState(lines: List.of(state.lines));
    } else {
      state = CartState(lines: [...state.lines, CartLine(product: p)]);
    }
  }

  void updateQty(String productId, num qty) {
    final lines = [...state.lines];
    for (final l in lines) {
      if (l.product.id == productId) l.qty = qty;
    }
    state = CartState(lines: lines);
  }

  void remove(String productId) {
    state = CartState(
        lines: state.lines.where((l) => l.product.id != productId).toList());
  }

  void clear() { state = CartState(); }

  Sale buildSale(
    String paymentMethod, {
    String? paymentRef,
    String? customerId,
    String? customerName,
    String? customerTin,
  }) {
    int subtotal = 0, vat = 0;
    final items = state.lines.map((l) {
      final cls = VatClass.fromName(l.product.vatClass);
      final split = VatEngine.splitInclusive(l.lineTotalCents, cls);
      subtotal += split.net;
      vat += split.vat;
      return SaleItem(
        id: _uuid.v4(),
        productId: l.product.id,
        nameSnapshot: l.product.name,
        qty: l.qty,
        unitPriceCents: l.product.priceCents,
        vatClass: l.product.vatClass,
        netCents: split.net,
        vatCents: split.vat,
      );
    }).toList();

    return Sale(
      id: _uuid.v4(),
      paymentMethod: paymentMethod,
      paymentRef: paymentRef,
      customerId: customerId,
      customerName: customerName,
      customerTin: customerTin,
      subtotalCents: subtotal,
      vatCents: vat,
      items: items,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
