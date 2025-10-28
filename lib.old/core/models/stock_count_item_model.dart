class StockCountItem {
  final String id;
  final String stockCountId;
  final String productId;
  final String productName;
  final double theoreticalQuantity;
  final double actualQuantity;
  final double variance;
  final double variancePercentage;
  final double costPerUnit;
  final double valueImpact;
  final String? adjustmentReason;
  final String? notes;
  final DateTime createdAt;
  final bool synced;

  StockCountItem({
    required this.id,
    required this.stockCountId,
    required this.productId,
    required this.productName,
    required this.theoreticalQuantity,
    required this.actualQuantity,
    required this.costPerUnit,
    this.adjustmentReason,
    this.notes,
    required this.createdAt,
    this.synced = false,
  })  : variance = actualQuantity - theoreticalQuantity,
        variancePercentage = theoreticalQuantity > 0
            ? ((actualQuantity - theoreticalQuantity) / theoreticalQuantity) *
                100
            : 0,
        valueImpact = (actualQuantity - theoreticalQuantity) * costPerUnit;

  factory StockCountItem.fromMap(Map<String, dynamic> map) {
    return StockCountItem(
      id: map['id'] as String,
      stockCountId: map['stock_count_id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      theoreticalQuantity: (map['theoretical_quantity'] as num).toDouble(),
      actualQuantity: (map['actual_quantity'] as num).toDouble(),
      costPerUnit: (map['cost_per_unit'] as num).toDouble(),
      adjustmentReason: map['adjustment_reason'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      synced: (map['synced'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stock_count_id': stockCountId,
      'product_id': productId,
      'product_name': productName,
      'theoretical_quantity': theoreticalQuantity,
      'actual_quantity': actualQuantity,
      'variance': variance,
      'variance_percentage': variancePercentage,
      'cost_per_unit': costPerUnit,
      'value_impact': valueImpact,
      'adjustment_reason': adjustmentReason,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  StockCountItem copyWith({
    String? id,
    String? stockCountId,
    String? productId,
    String? productName,
    double? theoreticalQuantity,
    double? actualQuantity,
    double? costPerUnit,
    String? adjustmentReason,
    String? notes,
    DateTime? createdAt,
    bool? synced,
  }) {
    return StockCountItem(
      id: id ?? this.id,
      stockCountId: stockCountId ?? this.stockCountId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      theoreticalQuantity: theoreticalQuantity ?? this.theoreticalQuantity,
      actualQuantity: actualQuantity ?? this.actualQuantity,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      adjustmentReason: adjustmentReason ?? this.adjustmentReason,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  bool get hasVariance => variance.abs() > 0.01; // Consider variance if > 0.01
  bool get isSignificantVariance => variancePercentage.abs() > 5.0; // > 5%
  bool get isPositiveVariance => variance > 0;
  bool get isNegativeVariance => variance < 0;

  String get varianceStatus {
    if (!hasVariance) return 'Match';
    if (isPositiveVariance) return 'Overage';
    return 'Shortage';
  }

  @override
  String toString() {
    return 'StockCountItem{id: $id, productName: $productName, variance: $variance}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StockCountItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
