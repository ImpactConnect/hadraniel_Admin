class IntakeBalance {
  final String id;
  final String productName;
  final double totalReceived;
  final double totalAssigned;
  final double balanceQuantity;
  final DateTime lastUpdated;

  IntakeBalance({
    required this.id,
    required this.productName,
    required this.totalReceived,
    required this.totalAssigned,
    required this.balanceQuantity,
    required this.lastUpdated,
  });

  factory IntakeBalance.fromMap(Map<String, dynamic> map) {
    return IntakeBalance(
      id: map['id'] as String,
      productName: map['product_name'] as String,
      totalReceived: (map['total_received'] as num).toDouble(),
      totalAssigned: (map['total_assigned'] as num).toDouble(),
      balanceQuantity: (map['balance_quantity'] as num).toDouble(),
      lastUpdated: DateTime.parse(map['last_updated'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_name': productName,
      'total_received': totalReceived,
      'total_assigned': totalAssigned,
      'balance_quantity': balanceQuantity,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  IntakeBalance copyWith({
    String? id,
    String? productName,
    double? totalReceived,
    double? totalAssigned,
    double? balanceQuantity,
    DateTime? lastUpdated,
  }) {
    return IntakeBalance(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      totalReceived: totalReceived ?? this.totalReceived,
      totalAssigned: totalAssigned ?? this.totalAssigned,
      balanceQuantity: balanceQuantity ?? this.balanceQuantity,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
