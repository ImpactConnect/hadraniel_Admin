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
  final bool isSynced;

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
    this.isSynced = false,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      quantity: map['quantity'] != null
          ? (map['quantity'] as num).toDouble()
          : 0.0,
      unit: map['unit']?.toString() ?? '',
      costPerUnit: map['cost_per_unit'] != null
          ? (map['cost_per_unit'] as num).toDouble()
          : 0.0,
      totalCost: map['total_cost'] != null
          ? (map['total_cost'] as num).toDouble()
          : 0.0,
      dateAdded: map['date_added'] != null
          ? DateTime.parse(map['date_added'] as String)
          : DateTime.now(),
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'] as String)
          : null,
      description: map['description']?.toString(),
      outletId: map['outlet_id']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
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
      'is_synced': isSynced ? 1 : 0,
    };
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
    bool? isSynced,
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
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
