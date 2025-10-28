import 'package:flutter/foundation.dart';

class StockBalance {
  final String id;
  final String outletId;
  final String productId;
  final double givenQuantity;
  final double soldQuantity;
  final double balanceQuantity;
  final DateTime? lastUpdated;
  final DateTime? createdAt;
  final bool synced;

  // Computed fields
  double? totalGivenValue;
  double? totalSoldValue;
  double? balanceValue;

  StockBalance({
    required this.id,
    required this.outletId,
    required this.productId,
    required this.givenQuantity,
    this.soldQuantity = 0,
    required this.balanceQuantity,
    this.lastUpdated,
    this.createdAt,
    this.synced = true,
    this.totalGivenValue,
    this.totalSoldValue,
    this.balanceValue,
  });

  factory StockBalance.fromJson(Map<String, dynamic> json) {
    return StockBalance(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      productId: json['product_id'] as String,
      givenQuantity: (json['given_quantity'] as num).toDouble(),
      soldQuantity: (json['sold_quantity'] as num?)?.toDouble() ?? 0,
      balanceQuantity: (json['balance_quantity'] as num).toDouble(),
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      synced: json['synced'] == 1,
    );
  }

  factory StockBalance.fromMap(Map<String, dynamic> map) {
    return StockBalance(
      id: map['id'] as String,
      outletId: map['outlet_id'] as String,
      productId: map['product_id'] as String,
      givenQuantity: (map['given_quantity'] as num).toDouble(),
      soldQuantity: (map['sold_quantity'] as num?)?.toDouble() ?? 0,
      balanceQuantity: (map['balance_quantity'] as num).toDouble(),
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      synced: (map['synced'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'product_id': productId,
      'given_quantity': givenQuantity,
      'sold_quantity': soldQuantity,
      'balance_quantity': balanceQuantity,
      'last_updated': lastUpdated?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  // Calculate values based on product cost
  void calculateValues(double costPerUnit) {
    totalGivenValue = givenQuantity * costPerUnit;
    totalSoldValue = soldQuantity * costPerUnit;
    balanceValue = balanceQuantity * costPerUnit;
  }

  @override
  String toString() {
    return 'StockBalance{id: $id, outletId: $outletId, productId: $productId, givenQuantity: $givenQuantity, soldQuantity: $soldQuantity, balanceQuantity: $balanceQuantity}';
  }
}