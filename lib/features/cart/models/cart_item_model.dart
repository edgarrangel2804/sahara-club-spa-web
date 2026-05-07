class CartItem {
  final String id;
  final String title;
  final double price;
  final String type; // 'physical', 'digital', 'membership'
  final String? image;

  CartItem({
    required this.id,
    required this.title,
    required this.price,
    required this.type,
    this.image,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      title: json['title'] as String,
      price: (json['price'] as num).toDouble(),
      type: json['type'] as String,
      image: json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'type': type,
      'image': image,
    };
  }
}
