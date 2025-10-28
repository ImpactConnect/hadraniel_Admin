class ProductDistribution {
  final String id;
  final String productName;
  final String outletId;
  final String outletName;
  final double quantity;
  final double costPerUnit;
  final double totalCost;
  final DateTime distributionDate;
  final DateTime createdAt;
  final bool isSynced;

  ProductDistribution({
    required this.id,
    required this.productName,
    required this.outletId,
    required this.outletName,
    required this.quantity,
    required this.costPerUnit,
    required this.totalCost,
    required this.distributionDate,
    required this.createdAt,
    this.isSynced = false,
  });

  factory ProductDistribution.fromMap(Map<String, dynamic> map) {
    return ProductDistribution(
      id: map['id'] as String,
      productName: map['product_name'] as String,
      outletId: map['outlet_id'] as String,
      outletName: map['outlet_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      costPerUnit: (map['cost_per_unit'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
      distributionDate: DateTime.parse(map['distribution_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      isSynced: (map['is_synced'] as int?) == 1,
    );
  }
  
  factory ProductDistribution.fromJson(Map<String, dynamic> json) {
    return ProductDistribution(
      id: json['id'] as String,
      productName: json['product_name'] as String,
      outletId: json['outlet_id'] as String,
      outletName: json['outlet_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      costPerUnit: (json['cost_per_unit'] as num).toDouble(),
      totalCost: (json['total_cost'] as num).toDouble(),
      distributionDate: DateTime.parse(json['distribution_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      isSynced: true, // Data from server is considered synced
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_name': productName,
      'outlet_id': outletId,
      'outlet_name': outletName,
      'quantity': quantity,
      'cost_per_unit': costPerUnit,
      'total_cost': totalCost,
      'distribution_date': distributionDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  ProductDistribution copyWith({
    String? id,
    String? productName,
    String? outletId,
    String? outletName,
    double? quantity,
    double? costPerUnit,
    double? totalCost,
    DateTime? distributionDate,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return ProductDistribution(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      outletId: outletId ?? this.outletId,
      outletName: outletName ?? this.outletName,
      quantity: quantity ?? this.quantity,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      totalCost: totalCost ?? this.totalCost,
      distributionDate: distributionDate ?? this.distributionDate,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
