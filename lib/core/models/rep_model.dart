class Rep {
  final String id;
  final String fullName;
  final String email;
  final String? outletId;
  final String role;
  final String? createdAt;

  Rep({
    required this.id,
    required this.fullName,
    required this.email,
    this.outletId,
    this.role = 'rep',
    this.createdAt,
  });

  factory Rep.fromMap(Map<String, dynamic> json) => Rep(
    id: json['id'] ?? '',
    fullName: json['full_name'] ?? '',
    email: json['email'] ?? '',
    outletId: json['outlet_id'],
    role: json['role'] ?? 'rep',
    createdAt: json['created_at']?.toString(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'outlet_id': outletId,
    'role': role,
    'created_at': createdAt,
  };

  Rep copyWith({
    String? id,
    String? fullName,
    String? email,
    String? outletId,
    String? role,
    String? createdAt,
  }) => Rep(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    outletId: outletId ?? this.outletId,
    role: role ?? this.role,
    createdAt: createdAt ?? this.createdAt,
  );
}
