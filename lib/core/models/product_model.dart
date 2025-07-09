class Product {
  final String id;
  final String name;
  final String unit;
  final double price;
  final List<String> outletIds;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.outletIds,
    required this.createdAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      unit: map['unit'] as String,
      price: (map['price'] as num).toDouble(),
      outletIds: List<String>.from(map['outlet_ids'] as List),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'price': price,
      'outlet_ids': outletIds,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? unit,
    double? price,
    List<String>? outletIds,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      outletIds: outletIds ?? this.outletIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
