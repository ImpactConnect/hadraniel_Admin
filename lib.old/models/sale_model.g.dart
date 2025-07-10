// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Sale _$SaleFromJson(Map<String, dynamic> json) => Sale(
  id: (json['id'] as num).toInt(),
  customerId: (json['customerId'] as num).toInt(),
  outletId: (json['outletId'] as num).toInt(),
  repId: (json['repId'] as num).toInt(),
  totalAmount: (json['totalAmount'] as num).toDouble(),
  paymentMethod: json['paymentMethod'] as String,
  status: json['status'] as String,
  saleDate: DateTime.parse(json['saleDate'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  lastUpdated: json['lastUpdated'] == null
      ? null
      : DateTime.parse(json['lastUpdated'] as String),
  items: (json['items'] as List<dynamic>?)
      ?.map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SaleToJson(Sale instance) => <String, dynamic>{
  'id': instance.id,
  'customerId': instance.customerId,
  'outletId': instance.outletId,
  'repId': instance.repId,
  'totalAmount': instance.totalAmount,
  'paymentMethod': instance.paymentMethod,
  'status': instance.status,
  'saleDate': instance.saleDate.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'lastUpdated': instance.lastUpdated?.toIso8601String(),
  'items': instance.items,
};
