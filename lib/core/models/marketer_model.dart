class Marketer {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String outletId; // Required - assigned branch/outlet
  final String status; // active, inactive, suspended
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';

  Marketer({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.outletId,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  factory Marketer.fromMap(Map<String, dynamic> json) => Marketer(
        id: json['id'] ?? '',
        fullName: json['full_name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'],
        outletId: json['outlet_id'] ?? '',
        status: json['status'] ?? 'active',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'outlet_id': outletId,
        'status': status,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Map<String, dynamic> toCloudMap() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'outlet_id': outletId,
        'status': status,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Marketer copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? outletId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Marketer(
        id: id ?? this.id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        outletId: outletId ?? this.outletId,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  String toString() {
    return 'Marketer{id: $id, fullName: $fullName, email: $email, outletId: $outletId, status: $status}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Marketer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
