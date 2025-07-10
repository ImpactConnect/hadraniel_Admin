class Sale {
  final String id;
  final String outletId;
  final String customerId;
  final double? totalAmount;
  final bool? isPaid;
  final DateTime? createdAt;

  Sale({
    required this.id,
    required this.outletId,
    required this.customerId,
    this.totalAmount,
    this.isPaid,
    this.createdAt,
  });

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as String,
      outletId: map['outlet_id'] as String,
      customerId: map['customer_id'] as String,
      totalAmount: map['total_amount'] as double?,
      isPaid: map['is_paid'] != null ? (map['is_paid'] as int) == 1 : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'customer_id': customerId,
      'total_amount': totalAmount,
      'is_paid': isPaid == null ? null : (isPaid! ? 1 : 0),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Sale copyWith({
    String? id,
    String? outletId,
    String? customerId,
    double? totalAmount,
    bool? isPaid,
    DateTime? createdAt,
  }) {
    return Sale(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      customerId: customerId ?? this.customerId,
      totalAmount: totalAmount ?? this.totalAmount,
      isPaid: isPaid ?? this.isPaid,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
