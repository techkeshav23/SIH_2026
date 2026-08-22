import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

class CartItem {
  final Product product;
  int qty;
  CartItem(this.product, this.qty);
  double get unit => product.finalPrice ?? product.suggestedPriceMax ?? 0;
  double get lineTotal => unit * qty;
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void add(Product p, {int qty = 1}) {
    final i = state.indexWhere((c) => c.product.id == p.id);
    if (i >= 0) {
      state[i].qty += qty;
      state = [...state];
    } else {
      state = [...state, CartItem(p, qty)];
    }
  }

  void setQty(String id, int qty) {
    if (qty <= 0) return remove(id);
    final i = state.indexWhere((c) => c.product.id == id);
    if (i >= 0) {
      state[i].qty = qty;
      state = [...state];
    }
  }

  void remove(String id) => state = state.where((c) => c.product.id != id).toList();
  void clear() => state = [];
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());

/// Total item count (sum of quantities) — for the cart badge.
final cartCountProvider = Provider<int>((ref) =>
    ref.watch(cartProvider).fold(0, (s, c) => s + c.qty));

/// Total value of the cart.
final cartTotalProvider = Provider<double>((ref) =>
    ref.watch(cartProvider).fold(0.0, (s, c) => s + c.lineTotal));
