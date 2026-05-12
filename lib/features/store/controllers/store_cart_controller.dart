import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/store_product.dart';

class StoreCartController extends ChangeNotifier {
  StoreCartController._();

  static final StoreCartController instance = StoreCartController._();

  final Map<String, CartItem> _items = <String, CartItem>{};

  List<CartItem> get items => _items.values.toList(growable: false);

  bool get isEmpty => _items.isEmpty;

  int get totalItems => _items.values.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );

  double get subtotal => _items.values.fold<double>(
        0,
        (sum, item) => sum + item.subtotal,
      );

  double get total => subtotal;

  Map<StoreProductType, List<CartItem>> get groupedItems {
    final groups = <StoreProductType, List<CartItem>>{};
    for (final item in _items.values) {
      groups.putIfAbsent(item.product.type, () => <CartItem>[]).add(item);
    }
    return groups;
  }

  void add(StoreProduct product) {
    final current = _items[product.id];
    if (current == null) {
      _items[product.id] = CartItem(product: product, quantity: 1);
    } else {
      _items[product.id] = current.copyWith(quantity: current.quantity + 1);
    }
    notifyListeners();
  }

  void decrease(String productId) {
    final current = _items[productId];
    if (current == null) return;
    if (current.quantity <= 1) {
      _items.remove(productId);
    } else {
      _items[productId] = current.copyWith(quantity: current.quantity - 1);
    }
    notifyListeners();
  }

  void increase(String productId) {
    final current = _items[productId];
    if (current == null) return;
    _items[productId] = current.copyWith(quantity: current.quantity + 1);
    notifyListeners();
  }

  void remove(String productId) {
    if (_items.remove(productId) != null) {
      notifyListeners();
    }
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
