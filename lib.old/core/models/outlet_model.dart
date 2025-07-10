class Outlet {
  final String id;
  final String name;
  final String? location;
  final DateTime createdAt;

  Outlet({
    required this.id,
    required this.name,
    this.location,
    required this.createdAt,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
    id: json['id'],
    name: json['name'],
    location: json['location'],
    createdAt: DateTime.parse(json['created_at']),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'location': location,
    'created_at': createdAt.toIso8601String(),
  };

  factory Outlet.fromMap(Map<String, dynamic> map) => Outlet(
    id: map['id'],
    name: map['name'],
    location: map['location'],
    createdAt: DateTime.parse(map['created_at']),
  );

  Outlet copyWith({
    String? id,
    String? name,
    String? location,
    DateTime? createdAt,
  }) => Outlet(
    id: id ?? this.id,
    name: name ?? this.name,
    location: location ?? this.location,
    createdAt: createdAt ?? this.createdAt,
  );
}
