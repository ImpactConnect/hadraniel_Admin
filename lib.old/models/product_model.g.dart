// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
  id: (json['id'] as num).toInt(),
  productName: json['productName'] as String,
  quantity: (json['quantity'] as num).toDouble(),
  unit: json['unit'] as String,
  costPerUnit: (json['costPerUnit'] as num).toDouble(),
  totalCost: (json['totalCost'] as num).toDouble(),
  dateAdded: DateTime.parse(json['dateAdded'] as String),
  lastUpdated: json['lastUpdated'] == null
      ? null
      : DateTime.parse(json['lastUpdated'] as String),
  description: json['description'] as String?,
  outletId: (json['outletId'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
  'id': instance.id,
  'productName': instance.productName,
  'quantity': instance.quantity,
  'unit': instance.unit,
  'costPerUnit': instance.costPerUnit,
  'totalCost': instance.totalCost,
  'dateAdded': instance.dateAdded.toIso8601String(),
  'lastUpdated': instance.lastUpdated?.toIso8601String(),
  'description': instance.description,
  'outletId': instance.outletId,
  'createdAt': instance.createdAt.toIso8601String(),
};
