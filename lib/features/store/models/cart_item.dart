import 'store_product.dart';

class CartItem {
  CartItem({
    required this.product,
    required this.quantity,
  });

  final StoreProduct product;
  final int quantity;

  double get subtotal => product.price * quantity;

  CartItem copyWith({
    StoreProduct? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}
