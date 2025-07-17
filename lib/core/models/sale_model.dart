class Sale {
  final String id;
  final String outletId;
  final String? customerId;
  final String? repId;
  final double vat;
  final double totalAmount;
  final double amountPaid;
  final double outstandingAmount;
  final bool isPaid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Sale({
    required this.id,
    required this.outletId,
    this.customerId,
    this.repId,
    this.vat = 0.0,
    this.totalAmount = 0.0,
    this.amountPaid = 0.0,
    this.outstandingAmount = 0.0,
    this.isPaid = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as String,
      outletId: map['outlet_id'] as String,
      customerId: map['customer_id'] as String?,
      repId: map['rep_id'] as String?,
      vat: map['vat'] != null ? (map['vat'] as num).toDouble() : 0.0,
      totalAmount: map['total_amount'] != null
          ? (map['total_amount'] as num).toDouble()
          : 0.0,
      amountPaid: map['amount_paid'] != null
          ? (map['amount_paid'] as num).toDouble()
          : 0.0,
      outstandingAmount: map['outstanding_amount'] != null
          ? (map['outstanding_amount'] as num).toDouble()
          : 0.0,
      isPaid: map['is_paid'] != null ? map['is_paid'] == 1 : false,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'customer_id': customerId,
      'rep_id': repId,
      'vat': vat,
      'total_amount': totalAmount,
      'amount_paid': amountPaid,
      'outstanding_amount': outstandingAmount,
      'is_paid': isPaid ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Sale copyWith({
    String? id,
    String? outletId,
    String? customerId,
    String? repId,
    double? vat,
    double? totalAmount,
    double? amountPaid,
    double? outstandingAmount,
    bool? isPaid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Sale(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      customerId: customerId ?? this.customerId,
      repId: repId ?? this.repId,
      vat: vat ?? this.vat,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      isPaid: isPaid ?? this.isPaid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
