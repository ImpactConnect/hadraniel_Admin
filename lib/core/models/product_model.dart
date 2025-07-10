class Product {
  final String id;
  final String name;
  final double? price;
  final int? quantity;
  final String? unit;
  final String? description;
  final String? category;
  final String? imageUrl;
  final DateTime? createdAt;
  final List<String>? outletIds;

  Product({
    required this.id,
    required this.name,
    this.price,
    this.quantity,
    this.unit,
    this.description,
    this.category,
    this.imageUrl,
    this.createdAt,
    this.outletIds,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      unit: map['unit'] as String?,
      price: map['price'] != null ? (map['price'] as num).toDouble() : null,
      quantity: map['quantity'] as int?,
      description: map['description'] as String?,
      category: map['category'] as String?,
      imageUrl: map['image_url'] as String?,
      outletIds: map['outlet_ids'] != null
          ? List<String>.from(map['outlet_ids'] as List)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'price': price,
      'quantity': quantity,
      'description': description,
      'category': category,
      'image_url': imageUrl,
      'outlet_ids': outletIds,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? unit,
    double? price,
    int? quantity,
    String? description,
    String? category,
    String? imageUrl,
    List<String>? outletIds,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      outletIds: outletIds ?? this.outletIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
