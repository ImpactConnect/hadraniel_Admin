class MarketerTarget {
  final String id;
  final String marketerId;
  final String productId;
  final String outletId;
  final double? targetQuantity; // Target quantity to sell
  final double? targetRevenue; // Target revenue to achieve
  final String targetType; // 'quantity', 'revenue', or 'both'
  final DateTime startDate;
  final DateTime endDate;
  final double currentQuantity; // Current achieved quantity
  final double currentRevenue; // Current achieved revenue
  final String status; // 'active', 'completed', 'expired', 'paused'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Calculated properties
  double get quantityProgress => targetQuantity != null && targetQuantity! > 0
      ? (currentQuantity / targetQuantity!) * 100
      : 0.0;

  double get revenueProgress => targetRevenue != null && targetRevenue! > 0
      ? (currentRevenue / targetRevenue!) * 100
      : 0.0;

  // Overall progress based on target type
  double get progressPercentage {
    if (targetType == 'quantity') {
      return quantityProgress;
    } else if (targetType == 'revenue') {
      return revenueProgress;
    } else if (targetType == 'both') {
      // For 'both' type, return the average of both progresses
      return (quantityProgress + revenueProgress) / 2;
    }
    return 0.0;
  }

  bool get isQuantityTarget => targetType == 'quantity' || targetType == 'both';
  bool get isRevenueTarget => targetType == 'revenue' || targetType == 'both';

  bool get isActive {
    final now = DateTime.now();
    return status == 'active' &&
        now.isAfter(startDate) &&
        now.isBefore(endDate.add(const Duration(days: 1)));
  }

  bool get isCompleted => progressPercentage >= 100.0;

  bool get isExpired {
    final now = DateTime.now();
    return now.isAfter(endDate.add(const Duration(days: 1)));
  }

  MarketerTarget({
    required this.id,
    required this.marketerId,
    required this.productId,
    required this.outletId,
    this.targetQuantity,
    this.targetRevenue,
    required this.targetType,
    required this.startDate,
    required this.endDate,
    this.currentQuantity = 0.0,
    this.currentRevenue = 0.0,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  factory MarketerTarget.fromMap(Map<String, dynamic> json) => MarketerTarget(
        id: json['id'] ?? '',
        marketerId: json['marketer_id'] ?? '',
        productId: json['product_id'] ?? '',
        outletId: json['outlet_id'] ?? '',
        targetQuantity: json['target_quantity']?.toDouble(),
        targetRevenue: json['target_revenue']?.toDouble(),
        targetType: json['target_type'] ?? 'quantity',
        startDate: DateTime.parse(json['start_date']),
        endDate: DateTime.parse(json['end_date']),
        currentQuantity: (json['current_quantity'] ?? 0.0).toDouble(),
        currentRevenue: (json['current_revenue'] ?? 0.0).toDouble(),
        status: json['status'] ?? 'active',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'marketer_id': marketerId,
        'product_id': productId,
        'outlet_id': outletId,
        'target_quantity': targetQuantity,
        'target_revenue': targetRevenue,
        'target_type': targetType,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'current_quantity': currentQuantity,
        'current_revenue': currentRevenue,
        'status': status,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Map<String, dynamic> toCloudMap() => {
        'id': id,
        'marketer_id': marketerId,
        'product_id': productId,
        'outlet_id': outletId,
        'target_quantity': targetQuantity,
        'target_revenue': targetRevenue,
        'target_type': targetType,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'current_quantity': currentQuantity,
        'current_revenue': currentRevenue,
        'status': status,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  MarketerTarget copyWith({
    String? id,
    String? marketerId,
    String? productId,
    String? outletId,
    double? targetQuantity,
    double? targetRevenue,
    String? targetType,
    DateTime? startDate,
    DateTime? endDate,
    double? currentQuantity,
    double? currentRevenue,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      MarketerTarget(
        id: id ?? this.id,
        marketerId: marketerId ?? this.marketerId,
        productId: productId ?? this.productId,
        outletId: outletId ?? this.outletId,
        targetQuantity: targetQuantity ?? this.targetQuantity,
        targetRevenue: targetRevenue ?? this.targetRevenue,
        targetType: targetType ?? this.targetType,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        currentQuantity: currentQuantity ?? this.currentQuantity,
        currentRevenue: currentRevenue ?? this.currentRevenue,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  String toString() {
    return 'MarketerTarget{id: $id, marketerId: $marketerId, productId: $productId, targetType: $targetType, status: $status}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketerTarget &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
