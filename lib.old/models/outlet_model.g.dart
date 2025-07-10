// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outlet_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Outlet _$OutletFromJson(Map<String, dynamic> json) => Outlet(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  location: json['location'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$OutletToJson(Outlet instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'location': instance.location,
  'createdAt': instance.createdAt.toIso8601String(),
};
