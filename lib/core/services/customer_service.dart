import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_model.dart';
import 'sync_service.dart';
import '../database/database_helper.dart';

class CustomerService {
  Database? _db;
  final SupabaseClient _supabase = Supabase.instance.client;
  final SyncService _syncService = SyncService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _dbHelper.database;
    return _db!;
  }

  Future<void> createCustomerTable() async {
    final db = await database;
    await db.execute(
      '''      CREATE TABLE IF NOT EXISTS customers (        id TEXT PRIMARY KEY,        full_name TEXT NOT NULL,        phone TEXT,        outlet_id TEXT,        total_outstanding REAL DEFAULT 0,        created_at TEXT NOT NULL,        is_synced INTEGER DEFAULT 0,        FOREIGN KEY (outlet_id) REFERENCES outlets (id)      )    ''',
    );
  }

  Future<Customer> createCustomer(Customer customer) async {
    final db = await database;
    await db.insert(
      'customers',
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    try {
      if (await _syncService.isOnline()) {
        await _supabase.from('customers').insert(customer.toMap());
      }
    } catch (e) {
      print('Error syncing customer to Supabase: $e');
      // Mark for future sync
      await _syncService.markForSync('customers', customer.id);
    }

    return customer;
  }

  Future<List<Customer>> getCustomers({String? outletId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: outletId != null ? 'outlet_id = ?' : null,
      whereArgs: outletId != null ? [outletId] : null,
    );

    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<Customer?> getCustomerById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );

    try {
      if (await _syncService.isOnline()) {
        await _supabase
            .from('customers')
            .update(customer.toMap())
            .eq('id', customer.id);
      }
    } catch (e) {
      print('Error syncing customer update to Supabase: $e');
      await _syncService.markForSync('customers', customer.id);
    }
  }

  Future<void> deleteCustomer(String id) async {
    final db = await database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);

    try {
      if (await _syncService.isOnline()) {
        await _supabase.from('customers').delete().eq('id', id);
      }
    } catch (e) {
      print('Error syncing customer deletion to Supabase: $e');
      await _syncService.markForSync('customers', id, isDelete: true);
    }
  }

  Future<void> syncCustomers() async {
    if (!await _syncService.isOnline()) return;

    try {
      final response = await _supabase.from('customers').select();
      final customers = (response as List)
          .map((customer) => Customer.fromMap(customer))
          .toList();

      final db = await database;
      final batch = db.batch();
      for (var customer in customers) {
        batch.insert(
          'customers',
          customer.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit();
    } catch (e) {
      print('Error syncing customers from Supabase: $e');
    }
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'full_name LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );

    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<List<Customer>> getCustomersWithOutstandingBalance() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'total_outstanding > 0',
    );

    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<double> getTotalOutstandingBalance() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(total_outstanding) as total FROM customers',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get customer purchase history with detailed information
  Future<List<Map<String, dynamic>>> getCustomerPurchaseHistory(
      String customerId) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT 
        s.id as sale_id,
        s.created_at,
        s.total_amount,
        s.amount_paid,
        s.outstanding_amount,
        (s.total_amount - s.amount_paid) as calculated_outstanding,
        s.is_paid,
        COUNT(si.id) as item_count,
        GROUP_CONCAT(COALESCE(p.product_name, 'Product ID: ' || si.product_id), ', ') as product_names,
        GROUP_CONCAT(si.quantity || ' x ' || COALESCE(p.product_name, 'Product ID: ' || si.product_id), ', ') as items_detail
      FROM sales s
      LEFT JOIN sale_items si ON si.sale_id = s.id
      LEFT JOIN products p ON si.product_id = p.id
      WHERE s.customer_id = ?
      GROUP BY s.id, s.created_at, s.total_amount, s.amount_paid, s.outstanding_amount, s.is_paid
      ORDER BY s.created_at DESC
    ''', [customerId]);

    return result
        .map((row) => {
              'sale_id': row['sale_id'] as String,
              'date': row['created_at'] as String,
              'total_amount': (row['total_amount'] as num?)?.toDouble() ?? 0.0,
              'amount_paid': (row['amount_paid'] as num?)?.toDouble() ?? 0.0,
              'outstanding_amount':
                  (row['calculated_outstanding'] as num?)?.toDouble() ?? 0.0,
              'is_paid': (row['is_paid'] as int?) == 1,
              'item_count': (row['item_count'] as int?) ?? 0,
              'product_names': (row['product_names'] as String?) ?? 'No items',
              'items_detail': (row['items_detail'] as String?) ?? 'No items',
            })
        .toList();
  }

  /// Get detailed sale items for a specific sale
  Future<List<Map<String, dynamic>>> getSaleItemsForSale(String saleId) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT 
        si.id,
        si.quantity,
        si.unit_price,
        si.total,
        COALESCE(p.product_name, 'Product ID: ' || si.product_id) as product_name,
        p.unit
      FROM sale_items si
      LEFT JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?
      ORDER BY p.product_name
    ''', [saleId]);

    return result
        .map((row) => {
              'id': row['id'] as String,
              'product_name': row['product_name'] as String,
              'quantity': (row['quantity'] as num?)?.toDouble() ?? 0.0,
              'unit_price': (row['unit_price'] as num?)?.toDouble() ?? 0.0,
              'total': (row['total'] as num?)?.toDouble() ?? 0.0,
              'unit': (row['unit'] as String?) ?? '',
            })
        .toList();
  }
}
