class ProductModel {
  final String id;
  final String name;
  final String description;
  final int price;
  final int? discountedPrice;
  final List<String> images;
  final String category;
  final int stock;
  final double rating;
  final int reviewsCount;
  final bool isAvailable;
  final List<String> specs;
  final DateTime createdAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.discountedPrice,
    this.images = const [],
    required this.category,
    this.stock = 0,
    this.rating = 0,
    this.reviewsCount = 0,
    this.isAvailable = true,
    this.specs = const [],
    required this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    price: json['price'],
    discountedPrice: json['discounted_price'],
    images: List<String>.from(json['images'] ?? []),
    category: json['category'],
    stock: json['stock'] ?? 0,
    rating: (json['rating'] ?? 0).toDouble(),
    reviewsCount: json['reviews_count'] ?? 0,
    isAvailable: json['is_available'] ?? true,
    specs: List<String>.from(json['specs'] ?? []),
    createdAt: DateTime.parse(json['created_at']),
  );
}
