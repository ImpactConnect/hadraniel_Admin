// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rep_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Rep _$RepFromJson(Map<String, dynamic> json) => Rep(
  id: (json['id'] as num).toInt(),
  fullName: json['fullName'] as String,
  email: json['email'] as String,
  outletId: (json['outletId'] as num?)?.toInt(),
  role: json['role'] as String? ?? 'rep',
  createdAt: DateTime.parse(json['createdAt'] as String),
  lastUpdated: json['lastUpdated'] == null
      ? null
      : DateTime.parse(json['lastUpdated'] as String),
);

Map<String, dynamic> _$RepToJson(Rep instance) => <String, dynamic>{
  'id': instance.id,
  'fullName': instance.fullName,
  'email': instance.email,
  'outletId': instance.outletId,
  'role': instance.role,
  'createdAt': instance.createdAt.toIso8601String(),
  'lastUpdated': instance.lastUpdated?.toIso8601String(),
};
