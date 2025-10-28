import 'dart:convert';

class DeletedSale {
  final String id;
  final String saleId;
  final String outletId;
  final String? customerId;
  final String? repId;
  final String deletedItemsJson; // Stored as TEXT in SQLite
  final double refundAmount;
  final String? reason;
  final DateTime? originalSaleDate;
  final DateTime deletedAt;
  final bool isSynced;

  DeletedSale({
    required this.id,
    required this.saleId,
    required this.outletId,
    this.customerId,
    this.repId,
    required this.deletedItemsJson,
    required this.refundAmount,
    this.reason,
    this.originalSaleDate,
    required this.deletedAt,
    this.isSynced = true,
  });

  factory DeletedSale.fromCloudJson(Map<String, dynamic> json) {
    return DeletedSale(
      id: json['id'] as String,
      saleId: json['sale_id'] as String,
      outletId: json['outlet_id'] as String,
      customerId: json['customer_id'] as String?,
      repId: json['rep_id'] as String?,
      deletedItemsJson: json['deleted_items_json'] is String
          ? json['deleted_items_json'] as String
          : jsonEncode(json['deleted_items_json']),
      refundAmount: (json['refund_amount'] as num).toDouble(),
      reason: json['reason'] as String?,
      originalSaleDate: json['original_sale_date'] != null
          ? DateTime.parse(json['original_sale_date'] as String)
          : null,
      deletedAt: DateTime.parse(json['deleted_at'] as String),
      isSynced: true,
    );
  }

  factory DeletedSale.fromMap(Map<String, dynamic> map) {
    return DeletedSale(
      id: map['id'] as String,
      saleId: map['sale_id'] as String,
      outletId: map['outlet_id'] as String,
      customerId: map['customer_id'] as String?,
      repId: map['rep_id'] as String?,
      deletedItemsJson: map['deleted_items_json'] as String,
      refundAmount: (map['refund_amount'] as num).toDouble(),
      reason: map['reason'] as String?,
      originalSaleDate: map['original_sale_date'] != null
          ? DateTime.parse(map['original_sale_date'] as String)
          : null,
      deletedAt: DateTime.parse(map['deleted_at'] as String),
      isSynced: (map['is_synced'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'outlet_id': outletId,
      'customer_id': customerId,
      'rep_id': repId,
      'deleted_items_json': deletedItemsJson,
      'refund_amount': refundAmount,
      'reason': reason,
      'original_sale_date': originalSaleDate?.toIso8601String(),
      'deleted_at': deletedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  int get deletedItemsCount {
    try {
      final data = jsonDecode(deletedItemsJson);
      if (data is List) return data.length;
      if (data is Map && data['items'] is List)
        return (data['items'] as List).length;
      return 0;
    } catch (_) {
      return 0;
    }
  }
}
