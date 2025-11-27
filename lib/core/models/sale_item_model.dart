class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final double quantity;
  final double unitPrice;
  final double total; // Maps to total_price in the cloud DB
  final String? productName;
  final DateTime? createdAt;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.createdAt,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as String,
      saleId: map['sale_id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String?,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      total: (map['total_price'] ?? map['total'] as num)
          .toDouble(), // Handle both old and new column names
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
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': total, // Updated to match database column name
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
    String? productName,
    double? quantity,
    double? unitPrice,
    double? total,
    DateTime? createdAt,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
