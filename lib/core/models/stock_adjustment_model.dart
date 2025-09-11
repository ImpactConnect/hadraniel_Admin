class StockAdjustment {
  final String id;
  final String productId;
  final String outletId;
  final String productName;
  final String outletName;
  final double adjustmentQuantity;
  final String adjustmentType; // 'increase', 'decrease'
  final String
      reason; // 'damaged', 'theft', 'expired', 'counting_error', 'system_error', 'other'
  final String? reasonDetails;
  final double costPerUnit;
  final double valueImpact;
  final String createdBy;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String status; // 'pending', 'approved', 'rejected'
  final String?
      stockCountId; // Reference to stock count if adjustment came from count
  final DateTime createdAt;
  final bool synced;

  StockAdjustment({
    required this.id,
    required this.productId,
    required this.outletId,
    required this.productName,
    required this.outletName,
    required this.adjustmentQuantity,
    required this.adjustmentType,
    required this.reason,
    this.reasonDetails,
    required this.costPerUnit,
    required this.createdBy,
    this.approvedBy,
    this.approvedAt,
    this.status = 'pending',
    this.stockCountId,
    required this.createdAt,
    this.synced = false,
  }) : valueImpact = adjustmentQuantity * costPerUnit;

  factory StockAdjustment.fromMap(Map<String, dynamic> map) {
    return StockAdjustment(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      outletId: map['outlet_id'] as String,
      productName: map['product_name'] as String,
      outletName: map['outlet_name'] as String,
      adjustmentQuantity: (map['adjustment_quantity'] as num).toDouble(),
      adjustmentType: map['adjustment_type'] as String,
      reason: map['reason'] as String,
      reasonDetails: map['reason_details'] as String?,
      costPerUnit: (map['cost_per_unit'] as num).toDouble(),
      createdBy: map['created_by'] as String,
      approvedBy: map['approved_by'] as String?,
      approvedAt: map['approved_at'] != null
          ? DateTime.parse(map['approved_at'] as String)
          : null,
      status: map['status'] as String? ?? 'pending',
      stockCountId: map['stock_count_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      synced: (map['synced'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'outlet_id': outletId,
      'product_name': productName,
      'outlet_name': outletName,
      'adjustment_quantity': adjustmentQuantity,
      'adjustment_type': adjustmentType,
      'reason': reason,
      'reason_details': reasonDetails,
      'cost_per_unit': costPerUnit,
      'value_impact': valueImpact,
      'created_by': createdBy,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'status': status,
      'stock_count_id': stockCountId,
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  StockAdjustment copyWith({
    String? id,
    String? productId,
    String? outletId,
    String? productName,
    String? outletName,
    double? adjustmentQuantity,
    String? adjustmentType,
    String? reason,
    String? reasonDetails,
    double? costPerUnit,
    String? createdBy,
    String? approvedBy,
    DateTime? approvedAt,
    String? status,
    String? stockCountId,
    DateTime? createdAt,
    bool? synced,
  }) {
    return StockAdjustment(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      outletId: outletId ?? this.outletId,
      productName: productName ?? this.productName,
      outletName: outletName ?? this.outletName,
      adjustmentQuantity: adjustmentQuantity ?? this.adjustmentQuantity,
      adjustmentType: adjustmentType ?? this.adjustmentType,
      reason: reason ?? this.reason,
      reasonDetails: reasonDetails ?? this.reasonDetails,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      status: status ?? this.status,
      stockCountId: stockCountId ?? this.stockCountId,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get requiresApproval =>
      valueImpact.abs() > 100.0; // Adjustments > $100 need approval

  String get reasonDisplayName {
    switch (reason) {
      case 'damaged':
        return 'Damaged Goods';
      case 'theft':
        return 'Theft/Shrinkage';
      case 'expired':
        return 'Expired Products';
      case 'counting_error':
        return 'Counting Error';
      case 'system_error':
        return 'System Error';
      case 'other':
        return 'Other';
      default:
        return reason;
    }
  }

  @override
  String toString() {
    return 'StockAdjustment{id: $id, productName: $productName, adjustmentQuantity: $adjustmentQuantity, reason: $reason}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StockAdjustment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
