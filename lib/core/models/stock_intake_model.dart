class StockIntake {
  final String id;
  final String productName;
  final double quantityReceived;
  final String unit;
  final double costPerUnit;
  final double totalCost;
  final String? description;
  final DateTime dateReceived;
  final DateTime createdAt;
  final bool isSynced;

  StockIntake({
    required this.id,
    required this.productName,
    required this.quantityReceived,
    required this.unit,
    required this.costPerUnit,
    required this.totalCost,
    this.description,
    required this.dateReceived,
    required this.createdAt,
    this.isSynced = false,
  });

  factory StockIntake.fromMap(Map<String, dynamic> map) {
    return StockIntake(
      id: map['id'] as String,
      productName: map['product_name'] as String,
      quantityReceived: (map['quantity_received'] as num).toDouble(),
      unit: map['unit'] as String,
      costPerUnit: (map['cost_per_unit'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
      description: map['description'] as String?,
      dateReceived: DateTime.parse(map['date_received'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      isSynced: map['is_synced'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_name': productName,
      'quantity_received': quantityReceived,
      'unit': unit,
      'cost_per_unit': costPerUnit,
      'total_cost': totalCost,
      'description': description,
      'date_received': dateReceived.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  StockIntake copyWith({
    String? id,
    String? productName,
    double? quantityReceived,
    String? unit,
    double? costPerUnit,
    double? totalCost,
    String? description,
    DateTime? dateReceived,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return StockIntake(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      unit: unit ?? this.unit,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      totalCost: totalCost ?? this.totalCost,
      description: description ?? this.description,
      dateReceived: dateReceived ?? this.dateReceived,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
