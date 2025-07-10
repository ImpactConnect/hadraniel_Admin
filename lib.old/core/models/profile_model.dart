class Profile {
  final String id;
  final String? outletId;
  final String fullName;
  final String role;
  final String? createdAt;

  Profile({
    required this.id,
    this.outletId,
    required this.fullName,
    required this.role,
    this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> json) => Profile(
    id: json['id'],
    outletId: json['outlet_id'],
    fullName: json['full_name'],
    role: json['role'],
    createdAt: json['created_at'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'outlet_id': outletId,
    'full_name': fullName,
    'role': role,
    'created_at': createdAt,
  };
}
