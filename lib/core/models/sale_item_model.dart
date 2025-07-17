class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final double quantity;
  final double unitPrice;
  final double total; // Maps to total_price in the cloud DB
  final DateTime? createdAt;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.createdAt,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    // Handle both 'total' and 'total_price' fields for compatibility
    final totalValue = map.containsKey('total_price')
        ? map['total_price']
        : (map.containsKey('total')
              ? map['total']
              : map['quantity'] * map['unit_price']);

    return SaleItem(
      id: map['id'] as String,
      saleId: map['sale_id'] as String,
      productId: map['product_id'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      total: (totalValue as num).toDouble(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total': total, // Used for local DB
      // We don't include total_price for cloud DB as it's a generated column
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // For syncing to cloud DB where total_price is a generated column
  Map<String, dynamic> toCloudMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      // No need to include total_price as it's generated in the cloud DB
    };
  }

  SaleItem copyWith({
    String? id,
    String? saleId,
    String? productId,
    double? quantity,
    double? unitPrice,
    double? total,
    DateTime? createdAt,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
