class Expenditure {
  final String id;
  final String description;
  final double amount;
  final String category;
  final String outletId;
  final String outletName;
  final DateTime dateIncurred;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isSynced;
  final String? vendorName;
  final String? receiptNumber;
  final String? paymentMethod;
  final String? notes;
  final bool isRecurring;
  final String? recurringFrequency;

  const Expenditure({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.outletId,
    required this.outletName,
    required this.dateIncurred,
    required this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.vendorName,
    this.receiptNumber,
    this.paymentMethod = 'cash',
    this.notes,
    this.isRecurring = false,
    this.recurringFrequency,
  });

  factory Expenditure.fromMap(Map<String, dynamic> map) {
    return Expenditure(
      id: map['id'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      outletId: map['outlet_id'] ?? '',
      outletName: map['outlet_name'] ?? '',
      dateIncurred: DateTime.parse(
          map['date_incurred'] ?? DateTime.now().toIso8601String()),
      createdAt:
          DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      isSynced: (map['is_synced'] ?? 0) == 1,
      vendorName: map['vendor_name'],
      receiptNumber: map['receipt_number'],
      paymentMethod: map['payment_method'] ?? 'cash',
      notes: map['notes'],
      isRecurring: (map['is_recurring'] ?? 0) == 1,
      recurringFrequency: map['recurring_frequency'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'category': category,
      'outlet_id': outletId,
      'outlet_name': outletName,
      'date_incurred': dateIncurred.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'vendor_name': vendorName,
      'receipt_number': receiptNumber,
      'payment_method': paymentMethod ?? 'cash',
      'notes': notes,
      'is_recurring': isRecurring ? 1 : 0,
      'recurring_frequency': recurringFrequency,
    };
  }

  Expenditure copyWith({
    String? id,
    String? description,
    double? amount,
    String? category,
    String? outletId,
    String? outletName,
    DateTime? dateIncurred,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? vendorName,
    String? receiptNumber,
    String? paymentMethod,
    String? notes,
    bool? isRecurring,
    String? recurringFrequency,
  }) {
    return Expenditure(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      outletId: outletId ?? this.outletId,
      outletName: outletName ?? this.outletName,
      dateIncurred: dateIncurred ?? this.dateIncurred,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      vendorName: vendorName ?? this.vendorName,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringFrequency: recurringFrequency ?? this.recurringFrequency,
    );
  }
}

class ExpenditureCategory {
  final String id;
  final String name;
  final String description;
  final String color;
  final bool isActive;
  final DateTime createdAt;

  ExpenditureCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    this.isActive = true,
    required this.createdAt,
  });

  factory ExpenditureCategory.fromMap(Map<String, dynamic> map) {
    return ExpenditureCategory(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      color: map['color'] ?? '#2196F3',
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static List<ExpenditureCategory> getDefaultCategories() {
    final now = DateTime.now();
    return [
      ExpenditureCategory(
        id: 'cat_utilities',
        name: 'Utilities',
        description: 'Electricity, water, gas, internet',
        color: '#FF9800',
        createdAt: now,
      ),
      ExpenditureCategory(
        id: 'cat_rent',
        name: 'Rent & Lease',
        description: 'Property rent, equipment lease',
        color: '#9C27B0',
        createdAt: now,
      ),
      ExpenditureCategory(
        id: 'cat_maintenance',
        name: 'Maintenance',
        description: 'Equipment repair, facility maintenance',
        color: '#607D8B',
        createdAt: now,
      ),
      ExpenditureCategory(
        id: 'cat_supplies',
        name: 'Office Supplies',
        description: 'Stationery, cleaning supplies, consumables',
        color: '#4CAF50',
        createdAt: now,
      ),
      ExpenditureCategory(
        id: 'cat_transport',
        name: 'Transportation',
        description: 'Fuel, vehicle maintenance, delivery costs',
        color: '#2196F3',
        createdAt: now,
      ),
      ExpenditureCategory(
        id: 'cat_marketing',
        name: 'Marketing',
        description: 'Advertising, promotional materials',
        color: '#E91E63',
        createdAt: now,
      ),
      ExpenditureCategory(
        id: 'cat_staff',
        name: 'Staff Expenses',
        description: 'Training, uniforms, staff welfare',
        color: '#795548',
        createdAt: now,
      ),
      ExpenditureCategory(
        id: 'cat_other',
        name: 'Other',
        description: 'Miscellaneous expenses',
        color: '#9E9E9E',
        createdAt: now,
      ),
    ];
  }
}
