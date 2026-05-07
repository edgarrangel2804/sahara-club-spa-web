class ProductModel {
  final String id;
  final String title;
  final String image;
  final double price;
  final bool isDigital;

  ProductModel({
    required this.id,
    required this.title,
    required this.image,
    required this.price,
    required this.isDigital,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      title: json['title'] as String,
      image: json['image'] as String,
      price: (json['price'] as num).toDouble(),
      isDigital: json['isDigital'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'price': price,
      'isDigital': isDigital,
    };
  }
}
