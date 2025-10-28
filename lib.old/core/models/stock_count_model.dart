class StockCount {
  final String id;
  final String outletId;
  final DateTime countDate;
  final String status; // 'in_progress', 'completed', 'cancelled'
  final String createdBy;
  final DateTime? completedAt;
  final String? notes;
  final DateTime createdAt;
  final bool synced;

  StockCount({
    required this.id,
    required this.outletId,
    required this.countDate,
    required this.status,
    required this.createdBy,
    this.completedAt,
    this.notes,
    required this.createdAt,
    this.synced = false,
  });

  factory StockCount.fromMap(Map<String, dynamic> map) {
    return StockCount(
      id: map['id'] as String,
      outletId: map['outlet_id'] as String,
      countDate: DateTime.parse(map['count_date'] as String),
      status: map['status'] as String,
      createdBy: map['created_by'] as String,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      synced: (map['synced'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'count_date': countDate.toIso8601String(),
      'status': status,
      'created_by': createdBy,
      'completed_at': completedAt?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  StockCount copyWith({
    String? id,
    String? outletId,
    DateTime? countDate,
    String? status,
    String? createdBy,
    DateTime? completedAt,
    String? notes,
    DateTime? createdAt,
    bool? synced,
  }) {
    return StockCount(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      countDate: countDate ?? this.countDate,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  String toString() {
    return 'StockCount{id: $id, outletId: $outletId, countDate: $countDate, status: $status}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StockCount && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
