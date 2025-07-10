// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SaleItem _$SaleItemFromJson(Map<String, dynamic> json) => SaleItem(
  id: (json['id'] as num).toInt(),
  saleId: (json['saleId'] as num).toInt(),
  productId: (json['productId'] as num).toInt(),
  quantity: (json['quantity'] as num).toDouble(),
  unitPrice: (json['unitPrice'] as num).toDouble(),
  totalPrice: (json['totalPrice'] as num).toDouble(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  lastUpdated: json['lastUpdated'] == null
      ? null
      : DateTime.parse(json['lastUpdated'] as String),
);

Map<String, dynamic> _$SaleItemToJson(SaleItem instance) => <String, dynamic>{
  'id': instance.id,
  'saleId': instance.saleId,
  'productId': instance.productId,
  'quantity': instance.quantity,
  'unitPrice': instance.unitPrice,
  'totalPrice': instance.totalPrice,
  'createdAt': instance.createdAt.toIso8601String(),
  'lastUpdated': instance.lastUpdated?.toIso8601String(),
};
