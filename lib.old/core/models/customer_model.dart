import 'package:uuid/uuid.dart';

class Customer {
  final String id;
  final String fullName;
  final String? phone;
  final String? outletId;
  final double totalOutstanding;
  final DateTime createdAt;

  Customer({
    String? id,
    required this.fullName,
    this.phone,
    this.outletId,
    this.totalOutstanding = 0.0,
    DateTime? createdAt,
  })
    : id = id ?? const Uuid().v4(),
      createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'outlet_id': outletId,
      'total_outstanding': totalOutstanding,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      fullName: map['full_name'],
      phone: map['phone'],
      outletId: map['outlet_id'],
      totalOutstanding: (map['total_outstanding'] ?? 0.0).toDouble(),
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Customer copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? outletId,
    double? totalOutstanding,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      outletId: outletId ?? this.outletId,
      totalOutstanding: totalOutstanding ?? this.totalOutstanding,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}