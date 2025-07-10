class Product {
  final String id;
  final String productName;
  final double quantity;
  final String unit;
  final double costPerUnit;
  final double totalCost;
  final DateTime dateAdded;
  final DateTime? lastUpdated;
  final String? description;
  final String outletId;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.costPerUnit,
    required this.totalCost,
    required this.dateAdded,
    this.lastUpdated,
    this.description,
    required this.outletId,
    required this.createdAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      productName: map['product_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      costPerUnit: (map['cost_per_unit'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
      dateAdded: DateTime.parse(map['date_added'] as String),
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'] as String)
          : null,
      description: map['description'] as String?,
      outletId: map['outlet_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_name': productName,
      'quantity': quantity,
      'unit': unit,
      'cost_per_unit': costPerUnit,
      'total_cost': totalCost,
      'date_added': dateAdded.toIso8601String(),
      'last_updated': lastUpdated?.toIso8601String(),
      'description': description,
      'outlet_id': outletId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final quantity = json['quantity'] != null
        ? (json['quantity'] as num).toDouble()
        : 0.0;
    final costPerUnit = json['cost_per_unit'] != null
        ? (json['cost_per_unit'] as num).toDouble()
        : 0.0;

    return Product(
      id: json['id'] as String,
      productName: json['product_name'] as String,
      quantity: quantity,
      unit: json['unit'] as String,
      costPerUnit: costPerUnit,
      totalCost: quantity * costPerUnit,
      dateAdded: json['date_added'] != null
          ? DateTime.parse(json['date_added'] as String)
          : DateTime.now(),
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : null,
      description: json['description'] as String?,
      outletId: json['outlet_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }

  Product copyWith({
    String? id,
    String? productName,
    double? quantity,
    String? unit,
    double? costPerUnit,
    double? totalCost,
    DateTime? dateAdded,
    DateTime? lastUpdated,
    String? description,
    String? outletId,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      totalCost: totalCost ?? this.totalCost,
      dateAdded: dateAdded ?? this.dateAdded,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      description: description ?? this.description,
      outletId: outletId ?? this.outletId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
