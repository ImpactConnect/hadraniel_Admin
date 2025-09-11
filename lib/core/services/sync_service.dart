import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/profile_model.dart';
import '../models/outlet_model.dart';
import '../models/product_model.dart';
import '../models/rep_model.dart';
import '../models/sale_model.dart';
import '../models/sale_item_model.dart';
import '../models/product_distribution_model.dart';
import '../models/stock_intake_model.dart';
import '../models/intake_balance_model.dart';
import '../database/database_helper.dart';
import 'stock_intake_service.dart';
import 'product_harmonization_utility.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  // Cache for outlet names to avoid repeated database queries
  final Map<String, String> _outletNameCache = {};
  final Map<String, Outlet> _outletCache = {};

  // Cache for customer names
  final Map<String, String> _customerNameCache = {};

  // Cache for rep names
  final Map<String, String> _repNameCache = {};

  // Public getter for database access
  Future<Database> get database => _dbHelper.database;

  // Sales methods
  Future<List<Sale>> getAllLocalSales() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Sale.fromMap(maps[i]));
  }

  Future<List<Map<String, dynamic>>> getSalesWithDetails({
    DateTime? startDate,
    DateTime? endDate,
    String? outletId,
    String? repId,
    String? productId,
  }) async {
    final db = await _dbHelper.database;

    // Build the main query to get sales with aggregated data
    String query;

    if (productId != null) {
      // When filtering by specific product, get the quantity of that specific product
      query = '''
        SELECT 
          s.id,
          s.created_at,
          s.outlet_id,
          s.customer_id,
          s.rep_id,
          s.total_amount,
          s.amount_paid,
          s.outstanding_amount,
          s.is_paid,
          COUNT(si.id) as item_count,
          CASE 
            WHEN COUNT(si.id) = 0 THEN 'No Items' 
            ELSE GROUP_CONCAT(COALESCE(p.product_name, 'Product ID: ' || si.product_id), ', ')
          END as product_names,
          CASE 
            WHEN COUNT(si.id) = 0 THEN 'No Items' 
            ELSE GROUP_CONCAT(si.quantity || ' x ' || COALESCE(p.product_name, 'Product ID: ' || si.product_id), ', ')
          END as items_detail,
          COALESCE((
            SELECT si2.quantity 
            FROM sale_items si2 
            WHERE si2.sale_id = s.id AND si2.product_id = ?
            LIMIT 1
          ), 0) as quantity
        FROM sales s
        LEFT JOIN sale_items si ON si.sale_id = s.id
        LEFT JOIN products p ON p.id = si.product_id
        WHERE s.id IN (SELECT DISTINCT sale_id FROM sale_items WHERE product_id = ?)
      ''';
    } else {
      // Original query for general sales data
      query = '''
        SELECT 
          s.id,
          s.created_at,
          s.outlet_id,
          s.customer_id,
          s.rep_id,
          s.total_amount,
          s.amount_paid,
          s.outstanding_amount,
          s.is_paid,
          COUNT(si.id) as item_count,
          CASE 
            WHEN COUNT(si.id) = 0 THEN 'No Items' 
            ELSE GROUP_CONCAT(COALESCE(p.product_name, 'Product ID: ' || si.product_id), ', ')
          END as product_names,
          CASE 
            WHEN COUNT(si.id) = 0 THEN 'No Items' 
            ELSE GROUP_CONCAT(si.quantity || ' x ' || COALESCE(p.product_name, 'Product ID: ' || si.product_id), ', ')
          END as items_detail
        FROM sales s
        LEFT JOIN sale_items si ON si.sale_id = s.id
        LEFT JOIN products p ON p.id = si.product_id
        WHERE 1=1
      ''';
    }

    List<dynamic> args = [];

    // Add product filter if provided (filter by sales that contain the product)
    if (productId != null) {
      args.add(productId); // For the subquery to get quantity
      args.add(productId); // For the main WHERE clause
    }

    // Add date range filter if provided
    if (startDate != null) {
      query += ' AND s.created_at >= ?';
      args.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      query += ' AND s.created_at <= ?';
      args.add(endDate.toIso8601String());
    }

    // Add outlet filter if provided
    if (outletId != null) {
      query += ' AND s.outlet_id = ?';
      args.add(outletId);
    }

    // Add rep filter if provided
    if (repId != null) {
      query += ' AND s.rep_id = ?';
      args.add(repId);
    }

    query += ' GROUP BY s.id ORDER BY s.created_at DESC';

    print('Executing query: $query');
    print('Query args: $args');

    final List<Map<String, dynamic>> sales = await db.rawQuery(query, args);
    print('Raw query results: $sales');

    List<Map<String, dynamic>> salesWithDetails = [];

    for (var sale in sales) {
      final saleOutletId = sale['outlet_id'] as String;
      final customerId = sale['customer_id'] as String?;
      final repId = sale['rep_id'] as String?;

      // Get outlet name
      String outletName = await getOutletName(saleOutletId);

      // Get customer name if customer_id is not null
      String customerName = '';
      if (customerId != null) {
        customerName = await getCustomerName(customerId);
      }

      // Get rep name if rep_id is not null
      String repName = 'N/A';
      if (repId != null) {
        repName = await getRepName(repId);
      }

      salesWithDetails.add({
        ...sale,
        'outlet_name': outletName,
        'customer_name': customerName,
        'rep_name': repName,
      });
    }

    print('Final sales with details: $salesWithDetails');
    return salesWithDetails;
  }

  // Helper methods for common date filters
  Future<List<Map<String, dynamic>>> getSalesToday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return getSalesWithDetails(startDate: today, endDate: tomorrow);
  }

  Future<List<Map<String, dynamic>>> getSalesYesterday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    return getSalesWithDetails(startDate: yesterday, endDate: today);
  }

  Future<List<Map<String, dynamic>>> getSalesLastSevenDays() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 7));
    final tomorrow = today.add(const Duration(days: 1));

    return getSalesWithDetails(startDate: sevenDaysAgo, endDate: tomorrow);
  }

  Future<List<Map<String, dynamic>>> getSalesThisMonth() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final nextMonth = (now.month < 12)
        ? DateTime(now.year, now.month + 1, 1)
        : DateTime(now.year + 1, 1, 1);

    return getSalesWithDetails(startDate: firstDayOfMonth, endDate: nextMonth);
  }

  Future<List<Map<String, dynamic>>> getSalesLastMonth() async {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final lastMonth = (now.month > 1)
        ? DateTime(now.year, now.month - 1, 1)
        : DateTime(now.year - 1, 12, 1);

    return getSalesWithDetails(startDate: lastMonth, endDate: thisMonth);
  }

  // Get sales metrics
  Future<Map<String, dynamic>> getSalesMetrics({
    DateTime? startDate,
    DateTime? endDate,
    String? outletId,
    String? repId,
    String? productId,
  }) async {
    final sales = await getSalesWithDetails(
      startDate: startDate,
      endDate: endDate,
      outletId: outletId,
      repId: repId,
      productId: productId,
    );

    double totalAmount = 0;
    double totalPaid = 0;
    double totalOutstanding = 0;
    int totalSales = sales.length;
    int totalItemsSold = 0;

    for (var sale in sales) {
      totalAmount += (sale['total_amount'] as num).toDouble();
      totalPaid += (sale['amount_paid'] as num).toDouble();
      totalOutstanding += (sale['outstanding_amount'] as num).toDouble();
      totalItemsSold += sale['item_count'] as int;
    }

    return {
      'total_sales': totalSales,
      'total_amount': totalAmount,
      'total_paid': totalPaid,
      'total_outstanding': totalOutstanding,
      'total_items_sold': totalItemsSold,
    };
  }

  Future<List<SaleItem>> getSaleItems(String saleId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return List.generate(maps.length, (i) => SaleItem.fromMap(maps[i]));
  }

  Future<List<Map<String, dynamic>>> getSaleItemsWithProductDetails(
    String saleId,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> items = await db.rawQuery(
      '''
      SELECT si.id, si.sale_id, si.product_id, si.quantity, 
             si.unit_price, si.total_price as total, si.created_at, 
             si.is_synced, COALESCE(p.product_name, 'Product ID: ' || si.product_id) as product_name 
      FROM sale_items si
      LEFT JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?
    ''',
      [saleId],
    );

    return items;
  }

  Future<String> getOutletName(String outletId) async {
    if (_outletNameCache.containsKey(outletId)) {
      return _outletNameCache[outletId]!;
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'outlets',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [outletId],
    );

    if (results.isNotEmpty) {
      final name = results.first['name'] as String;
      _outletNameCache[outletId] = name;
      return name;
    }
    return 'Unknown Outlet';
  }

  Future<String> getCustomerName(String customerId) async {
    if (_customerNameCache.containsKey(customerId)) {
      return _customerNameCache[customerId]!;
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'customers',
      columns: ['full_name'],
      where: 'id = ?',
      whereArgs: [customerId],
    );

    if (results.isNotEmpty) {
      final name = results.first['full_name'] as String;
      _customerNameCache[customerId] = name;
      return name;
    }
    return 'Unknown Customer';
  }

  Future<String> getRepName(String repId) async {
    if (_repNameCache.containsKey(repId)) {
      return _repNameCache[repId]!;
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'profiles',
      columns: ['full_name'],
      where: 'id = ?',
      whereArgs: [repId],
    );

    if (results.isNotEmpty) {
      final name = results.first['full_name'] as String;
      _repNameCache[repId] = name;
      return name;
    }
    return 'Unknown Rep';
  }

  // These caches are already declared at the top of the class
  // No need to redeclare them here

  Future<Map<String, int>> syncSalesToLocalDb() async {
    try {
      print('Syncing sales from cloud database...');
      print('Supabase client: ${supabase != null ? 'initialized' : 'null'}');
      print('Supabase URL: ${supabase.supabaseUrl}');
      print(
        'Supabase auth: ${supabase.auth.currentSession != null ? 'authenticated' : 'not authenticated'}',
      );

      // First sync local changes to cloud
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        final unsyncedSales = await txn.query(
          'sales',
          where: 'is_synced = ?',
          whereArgs: [0],
        );

        // Push unsynced sales to Supabase
        for (var saleMap in unsyncedSales) {
          final sale = Sale.fromMap(saleMap);
          await supabase.from('sales').upsert(sale.toMap());

          // Mark as synced locally
          await txn.update(
            'sales',
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [sale.id],
          );

          // Also sync the sale items
          final saleItems = await txn.query(
            'sale_items',
            where: 'sale_id = ?',
            whereArgs: [sale.id],
          );

          for (var itemMap in saleItems) {
            final item = SaleItem.fromMap(itemMap);
            await supabase.from('sale_items').upsert(item.toCloudMap());

            // Mark as synced locally
            await txn.update(
              'sale_items',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [item.id],
            );
          }
        }
      });

      final response = await supabase.from('sales').select();
      print('Raw response: $response');
      final sales = response as List<dynamic>;
      print('Found ${sales.length} sales in cloud database');

      // Use a single transaction for the entire sync operation to prevent database locking
      await db.transaction((txn) async {
        // First check if we have any sales in the local database
        final localCount = Sqflite.firstIntValue(
          await txn.rawQuery('SELECT COUNT(*) FROM sales'),
        );
        print('Local sales count: $localCount');

        // Only clear and re-insert if we have data to sync or if local DB is empty
        if (sales.isNotEmpty || localCount == 0) {
          // Clear existing sales and sale_items within the transaction
          await txn.delete('sale_items');
          await txn.delete('sales');

          // Insert new sales
          for (final saleData in sales) {
            try {
              print('Processing sale: ${saleData['id']}');
              final sale = Sale.fromMap(saleData as Map<String, dynamic>);
              print(
                'Mapped to Sale: ${sale.id}, outletId: ${sale.outletId}, totalAmount: ${sale.totalAmount}',
              );
              await txn.insert('sales', {...sale.toMap(), 'is_synced': 1});
            } catch (e) {
              print('Error processing sale ${saleData['id']}: $e');
              print('Raw sale data: $saleData');
              // Continue with next sale instead of failing the entire transaction
            }
          }
          print('Successfully synced ${sales.length} sales to local database');
        } else {
          print('No sales to sync from cloud database');
        }
      });

      // Sync sale items in a separate transaction
      await syncSaleItemsToLocalDb();

      // Count total synced records
      final salesCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM sales')) ??
          0;
      final itemsCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM sale_items')) ??
          0;

      return {
        'synced': salesCount + itemsCount,
        'sales': salesCount,
        'items': itemsCount
      };
    } catch (e) {
      print('Error syncing sales: $e');
      rethrow;
    }
  }

  Future<void> syncSaleItemsToLocalDb() async {
    try {
      print('Syncing sale items from cloud database...');
      print(
        'Supabase client for sale items: ${supabase != null ? 'initialized' : 'null'}',
      );

      List<dynamic> saleItems = [];
      try {
        final response = await supabase.from('sale_items').select();
        print('Raw sale_items response: $response');
        saleItems = response as List<dynamic>;
        print('Found ${saleItems.length} sale items in cloud database');
      } catch (queryError) {
        print('Error querying sale_items table: $queryError');
        // Check if the table exists
        print('Checking if sale_items table exists...');
        try {
          final tablesResponse = await supabase.rpc('list_tables');
          print('Available tables: $tablesResponse');
        } catch (e) {
          print('Could not list tables: $e');
        }
        rethrow;
      }

      final db = await _dbHelper.database;

      // Use a transaction for the entire sync operation to prevent database locking
      await db.transaction((txn) async {
        // First check if we have any sale items in the local database
        final localCount = Sqflite.firstIntValue(
          await txn.rawQuery('SELECT COUNT(*) FROM sale_items'),
        );
        print('Local sale items count: $localCount');

        // Only clear and re-insert if we have data to sync or if local DB is empty
        if (saleItems.isNotEmpty || localCount == 0) {
          // Clear existing sale items within the transaction
          await txn.delete('sale_items');

          // Insert new sale items
          for (final itemData in saleItems) {
            try {
              print('Processing sale item: ${itemData['id']}');
              final saleItem =
                  SaleItem.fromMap(itemData as Map<String, dynamic>);
              print(
                'Mapped to SaleItem: ${saleItem.id}, saleId: ${saleItem.saleId}, productId: ${saleItem.productId}',
              );
              await txn
                  .insert('sale_items', {...saleItem.toMap(), 'is_synced': 1});
            } catch (e) {
              print('Error processing sale item ${itemData['id']}: $e');
              print('Raw item data: $itemData');
              // Continue with next item instead of failing the entire transaction
            }
          }
          print(
            'Successfully synced ${saleItems.length} sale items to local database',
          );
        } else {
          print('No sale items to sync from cloud database');
        }
      });
    } catch (e) {
      print('Error syncing sale items: $e');
      rethrow;
    }
  }

  final supabase = Supabase.instance.client;
  // DatabaseHelper instance is already declared at the top of the class

  // Reset Database
  Future<void> resetDatabase() async {
    try {
      print('Resetting database...');
      await _dbHelper.deleteDatabase();
      print('Database reset completed.');
    } catch (e) {
      print('Error resetting database: $e');
      throw e;
    }
  }

  // Profiles Sync
  Future<void> syncProfilesToLocalDb() async {
    try {
      final response = await supabase.from('profiles').select();
      final profiles =
          (response as List).map((data) => Profile.fromMap(data)).toList();

      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        for (var profile in profiles) {
          await txn.insert(
            'profiles',
            profile.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      print('Error syncing profiles: $e');
      throw e;
    }
  }

  // Outlets Sync
  Future<Map<String, int>> syncOutletsToLocalDb([List<Outlet>? outlets]) async {
    try {
      final outletsToSync = outlets ??
          (await supabase.from('outlets').select() as List)
              .map((data) => Outlet.fromMap(data))
              .toList();

      final db = await _dbHelper.database;
      int syncedCount = 0;
      await db.transaction((txn) async {
        for (var outlet in outletsToSync) {
          await txn.insert(
            'outlets',
            outlet.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          syncedCount++;
        }
      });

      return {'synced': syncedCount, 'total': outletsToSync.length};
    } catch (e) {
      print('Error syncing outlets: $e');
      throw e;
    }
  }

  // Sync outlets from local database to cloud
  Future<int> syncOutletsToCloud() async {
    try {
      final db = await _dbHelper.database;
      int syncedCount = 0;

      // Get all local outlets
      final localOutlets = await db.query('outlets');
      
      print('Found ${localOutlets.length} local outlets to sync to cloud');

      for (var outletMap in localOutlets) {
        final outlet = Outlet.fromMap(outletMap);

        try {
          // Check if outlet exists in cloud first
          final existingCloudOutlet = await supabase
              .from('outlets')
              .select()
              .eq('id', outlet.id)
              .maybeSingle();

          if (existingCloudOutlet != null) {
            // Outlet exists in cloud, update it
            await supabase
                .from('outlets')
                .update({
                  'name': outlet.name,
                  'location': outlet.location,
                })
                .eq('id', outlet.id);
            print('Updated existing outlet ${outlet.id} in cloud');
          } else {
            // Outlet doesn't exist in cloud, insert it
            await supabase.from('outlets').insert({
              'id': outlet.id,
              'name': outlet.name,
              'location': outlet.location,
            });
            print('Inserted new outlet ${outlet.id} to cloud');
          }

          syncedCount++;
        } catch (e) {
          print('Error syncing outlet ${outlet.id} to cloud: $e');
          // Continue with other outlets instead of failing entire sync
        }
      }

      return syncedCount;
    } catch (e) {
      print('Error syncing outlets to cloud: $e');
      throw e;
    }
  }

  // Insert or update outlet in local database
  Future<void> insertOrUpdateOutlet(Outlet outlet) async {
    try {
      final db = await _dbHelper.database;
      
      await db.insert(
        'outlets',
        outlet.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('Successfully inserted/updated outlet: ${outlet.name}');
    } catch (e) {
      print('Error inserting/updating outlet: $e');
      throw e;
    }
  }

  // Products Management
  Future<void> insertProduct(Product product) async {
    try {
      final db = await _dbHelper.database;

      // Always create new product entry - no harmonization
      // Each product assignment should have its own unique record
      await db.insert('products', {...product.toMap(), 'is_synced': 0});

      // Update the intake balance when a product is assigned to an outlet
      final stockIntakeService = StockIntakeService();
      final outletName = await getOutletName(product.outletId);
      await stockIntakeService.updateBalanceOnProductAssignment(
        product.productName,
        product.quantity,
        product.outletId,
        outletName,
        product.costPerUnit,
      );
    } catch (e) {
      print('Error inserting product: $e');
      throw e;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      final db = await _dbHelper.database;
      
      // Update the existing product record with the same ID
      final updatedProduct = Product(
        id: product.id, // Keep the same ID
        productName: product.productName,
        quantity: product.quantity,
        unit: product.unit,
        costPerUnit: product.costPerUnit,
        totalCost: product.quantity * product.costPerUnit, // Recalculate total cost
        dateAdded: product.dateAdded, // Keep original date added
        lastUpdated: DateTime.now(), // Update the last updated timestamp
        description: product.description,
        outletId: product.outletId,
        createdAt: product.createdAt, // Keep original creation time
        isSynced: false, // Mark as unsynced for cloud sync
      );

      // Update the existing record in the database
      await db.update(
        'products',
        updatedProduct.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );

      // Add to sync queue for cloud synchronization
      await _addToSyncQueue('products', product.id);
    } catch (e) {
      print('Error updating product: $e');
      throw e;
    }
  }

  // Helper method to add items to sync queue
  Future<void> _addToSyncQueue(String tableName, String recordId,
      {bool isDelete = false}) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('sync_queue', {
        'table_name': tableName,
        'record_id': recordId,
        'is_delete': isDelete ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error adding to sync queue: $e');
    }
  }

  /// Checks if a product is referenced by other tables
  /// Returns a map with 'canDelete' boolean and 'message' string
  Future<Map<String, dynamic>> canDeleteProduct(String productId) async {
    final db = await _dbHelper.database;

    // Check if product is referenced in sale_items
    final saleItemsCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM sale_items WHERE product_id = ?',
          [productId],
        )) ??
        0;

    if (saleItemsCount > 0) {
      return {
        'canDelete': false,
        'message':
            'Cannot delete this product because it is used in $saleItemsCount sales record(s). '
                'Please remove all related sales records before deleting this product.'
      };
    }

    // Check if product is referenced in stock_balances
    final stockBalancesCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM stock_balances WHERE product_id = ?',
          [productId],
        )) ??
        0;

    if (stockBalancesCount > 0) {
      return {
        'canDelete': false,
        'message':
            'Cannot delete this product because it is used in $stockBalancesCount stock balance record(s). '
                'Please remove all related stock records before deleting this product.'
      };
    }

    // Product can be deleted
    return {'canDelete': true, 'message': ''};
  }

  Future<void> deleteProduct(String productId) async {
    try {
      final db = await _dbHelper.database;

      // Get the product details before deleting
      final List<Map<String, dynamic>> productMaps = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (productMaps.isNotEmpty) {
        final product = Product.fromMap(productMaps.first);

        try {
          // Delete the product locally
          await db.delete('products', where: 'id = ?', whereArgs: [productId]);

          // Update the balance by adding back the quantity (negative assignment)
          final stockIntakeService = StockIntakeService();
          final outletName = await getOutletName(product.outletId);
          await stockIntakeService.updateBalanceOnProductAssignment(
            product.productName,
            -product.quantity, // Negative quantity to add back to balance
            product.outletId,
            outletName,
            product.costPerUnit,
          );

          // Sync deletion to cloud database
          if (await isOnline()) {
            try {
              // Delete from cloud database immediately if online
              await supabase.from('products').delete().eq('id', productId);
            } catch (e) {
              print('Error deleting product from cloud: $e');

              // Check for foreign key constraint violation in Supabase
              String errorMessage = e.toString();
              if (errorMessage.contains('violates foreign key constraint')) {
                if (errorMessage.contains('sale_items')) {
                  // Create a more user-friendly error message for sales records
                  throw Exception(
                      'Cannot delete this product because it is being used in sales records on the server. '
                      'Please remove all related sales records before deleting this product.');
                } else if (errorMessage.contains('stock_balances')) {
                  // Create a more user-friendly error message for stock balances
                  throw Exception(
                      'Cannot delete this product because it is being used in stock balance records on the server. '
                      'Please remove all related stock records before deleting this product.');
                } else {
                  // Generic foreign key constraint message
                  throw Exception(
                      'Cannot delete this product because it is referenced by other records on the server. '
                      'Please remove all related records before deleting this product.');
                }
              }

              // If cloud deletion fails for other reasons, mark for sync to retry later
              await _addToSyncQueue('products', productId, isDelete: true);
            }
          } else {
            // If offline, mark for sync when connection is restored
            await _addToSyncQueue('products', productId, isDelete: true);
          }
        } catch (e) {
          String errorMessage = e.toString();

          // Check for foreign key constraint violation
          if (errorMessage.contains('FOREIGN KEY constraint failed')) {
            // Try to determine which table is causing the constraint violation
            if (errorMessage.toLowerCase().contains('sale_items')) {
              throw Exception(
                  'Cannot delete this product because it is being used in sales records. '
                  'Please remove all related sales records before deleting this product.');
            } else if (errorMessage.toLowerCase().contains('stock_balances')) {
              throw Exception(
                  'Cannot delete this product because it is being used in stock balance records. '
                  'Please remove all related stock records before deleting this product.');
            } else {
              // Generic foreign key constraint message
              throw Exception(
                  'Cannot delete this product because it is being used in other records. '
                  'Please remove all related records before deleting this product.');
            }
          } else {
            // For other errors, rethrow with original message
            print('Error deleting product: $e');
            throw e;
          }
        }
      } else {
        // If product doesn't exist locally, still try to delete from cloud if online
        if (await isOnline()) {
          try {
            await supabase.from('products').delete().eq('id', productId);
          } catch (e) {
            print('Error deleting non-existent product from cloud: $e');
            // Mark for sync in case the product exists in cloud but not locally
            await _addToSyncQueue('products', productId, isDelete: true);
          }
        } else {
          // Mark for sync when connection is restored
          await _addToSyncQueue('products', productId, isDelete: true);
        }
      }
    } catch (e) {
      print('Error deleting product: $e');
      throw e;
    }
  }

  Future<List<Outlet>> getAllLocalOutlets() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('outlets');
      return List.generate(maps.length, (i) => Outlet.fromMap(maps[i]));
    } catch (e) {
      print('Error getting all local outlets: $e');
      return [];
    }
  }

  // Method removed as it was redundant with getOutletName

  // Synchronous version that uses the cache
  String? getOutletNameSync(String outletId) {
    return _outletNameCache[outletId];
  }

  Future<Outlet?> getOutletById(String outletId) async {
    // Check cache first
    if (_outletCache.containsKey(outletId)) {
      return _outletCache[outletId];
    }

    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'outlets',
        where: 'id = ?',
        whereArgs: [outletId],
        limit: 1,
      );
      if (results.isNotEmpty) {
        final outlet = Outlet.fromMap(results.first);
        // Cache the result
        _outletCache[outletId] = outlet;
        _outletNameCache[outletId] = outlet.name;
        return outlet;
      }
      return null;
    } catch (e) {
      print('Error getting outlet by id: $e');
      return null;
    }
  }

  // Product Distributions Sync
  Future<void> syncProductDistributionsToServer() async {
    try {
      final db = await _dbHelper.database;

      // Use a transaction to query unsynchronized distributions
      await db.transaction((txn) async {
        final List<Map<String, dynamic>> maps = await txn.query(
          'product_distributions',
          where: 'is_synced = ?',
          whereArgs: [0],
        );

        final distributions =
            maps.map((map) => ProductDistribution.fromMap(map)).toList();

        for (var distribution in distributions) {
          // Upload to Supabase
          await supabase.from('product_distributions').upsert({
            'id': distribution.id,
            'product_name': distribution.productName,
            'outlet_id': distribution.outletId,
            'outlet_name': distribution.outletName,
            'quantity': distribution.quantity,
            'cost_per_unit': distribution.costPerUnit,
            'total_cost': distribution.totalCost,
            'distribution_date':
                distribution.distributionDate.toIso8601String(),
            'created_at': distribution.createdAt.toIso8601String(),
          });

          // Mark as synced in local DB within the transaction
          await txn.update(
            'product_distributions',
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [distribution.id],
          );
        }
      });
    } catch (e) {
      print('Error syncing product distributions to server: $e');
      throw e;
    }
  }

  Future<void> syncProductDistributionsFromServer() async {
    try {
      final StockIntakeService stockIntakeService = StockIntakeService();
      final response = await supabase.from('product_distributions').select();
      final serverDistributions = (response as List)
          .map((data) => ProductDistribution.fromJson(data))
          .toList();

      final db = await _dbHelper.database;

      // Get existing local distributions
      final List<Map<String, dynamic>> localMaps = await db.query(
        'product_distributions',
      );
      final localDistributions =
          localMaps.map((map) => ProductDistribution.fromMap(map)).toList();

      // Create a map of local distributions by ID for easy lookup
      final Map<String, ProductDistribution> localDistributionsMap = {
        for (var dist in localDistributions) dist.id: dist,
      };

      await db.transaction((txn) async {
        // Update or insert server distributions
        for (var serverDist in serverDistributions) {
          if (localDistributionsMap.containsKey(serverDist.id)) {
            // Distribution exists locally, update if needed
            await txn.update(
              'product_distributions',
              serverDist.toMap()..['is_synced'] = 1,
              where: 'id = ?',
              whereArgs: [serverDist.id],
            );
          } else {
            // New distribution from server, insert it
            await txn.insert(
              'product_distributions',
              serverDist.toMap()..['is_synced'] = 1,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });
    } catch (e) {
      print('Error syncing product distributions from server: $e');
      throw e;
    }
  }

  Future<Product?> getProductById(String productId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return Product.fromMap(results.first);
      }
      return null;
    } catch (e) {
      print('Error getting product by id: $e');
      throw e;
    }
  }

  // Products Sync
  // Separate method to push local products to cloud
  Future<int> syncProductsToCloud() async {
    try {
      final db = await _dbHelper.database;
      int syncedCount = 0;

      // Process sync queue first to handle any pending deletions
      await processSyncQueue();

      // Push unsynced local products to cloud
      await db.transaction((txn) async {
        final unsyncedProducts = await txn.query(
          'products',
          where: 'is_synced = ?',
          whereArgs: [0],
        );

        print(
            'Found ${unsyncedProducts.length} unsynced products to push to cloud');

        for (var productMap in unsyncedProducts) {
          final product = Product.fromMap(productMap);

          try {
            // Check if product exists in cloud first
            final existingCloudProduct = await supabase
                .from('products')
                .select()
                .eq('id', product.id)
                .maybeSingle();

            if (existingCloudProduct != null) {
              // Product exists in cloud, update it
              await supabase
                  .from('products')
                  .update(product.toCloudMap())
                  .eq('id', product.id);
              print('Updated existing product ${product.id} in cloud');
            } else {
              // Product doesn't exist in cloud, insert it
              await supabase.from('products').insert(product.toCloudMap());
              print('Inserted new product ${product.id} to cloud');
            }

            // Mark as synced locally
            await txn.update(
              'products',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [product.id],
            );
            syncedCount++;
          } catch (e) {
            print('Error syncing product ${product.id} to cloud: $e');
            // Continue with other products instead of failing entire sync
          }
        }
      });

      return syncedCount;
    } catch (e) {
      print('Error syncing products to cloud: $e');
      throw e;
    }
  }

  // Separate method to fetch products from cloud to local (only when local data is missing)
  Future<int> fetchProductsFromCloud() async {
    try {
      final db = await _dbHelper.database;
      int fetchedCount = 0;

      // Get all local product IDs to check what's missing
      final localProductIds = await db.query(
        'products',
        columns: ['id'],
      );
      final localIds =
          localProductIds.map((row) => row['id'] as String).toSet();

      // Fetch all products from cloud
      final response = await supabase.from('products').select();
      print('Fetched ${(response as List).length} products from cloud');

      final cloudProducts = (response as List)
          .map((data) {
            try {
              return Product.fromMap(data);
            } catch (e) {
              print('Error processing cloud product: $data');
              print('Error details: $e');
              return null;
            }
          })
          .where((product) => product != null)
          .cast<Product>()
          .toList();

      final stockIntakeService = StockIntakeService();
      final List<Map<String, dynamic>> balanceUpdateData = [];

      // Only process products that don't exist locally
      final missingProducts = cloudProducts
          .where((product) => !localIds.contains(product.id))
          .toList();

      print(
          'Found ${missingProducts.length} missing products to fetch from cloud');

      if (missingProducts.isNotEmpty) {
        await db.transaction((txn) async {
          for (var product in missingProducts) {
            // Insert the missing product locally
            await txn.insert(
              'products',
              {
                ...product.toMap(),
                'is_synced': 1, // Mark as synced since it came from cloud
              },
              conflictAlgorithm:
                  ConflictAlgorithm.ignore, // Ignore if somehow exists
            );

            // Add to balance update data for new products
            balanceUpdateData.add({
              'productName': product.productName,
              'quantity': product.quantity,
              'outletId': product.outletId,
              'costPerUnit': product.costPerUnit,
            });

            fetchedCount++;
            print('Fetched missing product ${product.id} from cloud');
          }
        });

        // Update intake balances for newly fetched products
        for (var updateData in balanceUpdateData) {
          final outletName = await getOutletName(updateData['outletId']);
          await stockIntakeService.updateBalanceOnProductAssignment(
            updateData['productName'],
            updateData['quantity'],
            updateData['outletId'],
            outletName,
            updateData['costPerUnit'],
          );
        }
      }

      return fetchedCount;
    } catch (e) {
      print('Error fetching products from cloud: $e');
      throw e;
    }
  }

  // Combined sync method that handles both directions intelligently
  Future<Map<String, int>> syncProductsToLocalDb() async {
    try {
      print('Starting intelligent product sync...');

      // First, push any local changes to cloud
      final uploadedCount = await syncProductsToCloud();

      // Then, fetch any missing products from cloud
      final downloadedCount = await fetchProductsFromCloud();

      final totalSynced = uploadedCount + downloadedCount;
      print(
          'Product sync completed successfully - uploaded: $uploadedCount, downloaded: $downloadedCount');

      return {
        'synced': totalSynced,
        'uploaded': uploadedCount,
        'downloaded': downloadedCount
      };
    } catch (e) {
      print('Error in product sync: $e');
      throw e;
    }
  }

  // Reps Sync
  Future<Map<String, int>> syncRepsToLocalDb() async {
    try {
      final response =
          await supabase.from('profiles').select().eq('role', 'rep');
      final reps = (response as List).map((data) => Rep.fromMap(data)).toList();

      final db = await _dbHelper.database;
      int syncedCount = 0;
      await db.transaction((txn) async {
        // Clear existing reps
        await txn.delete('reps');
        // Insert new reps
        for (var rep in reps) {
          await txn.insert(
            'reps',
            rep.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          syncedCount++;
        }
      });

      return {'synced': syncedCount, 'total': reps.length};
    } catch (e) {
      print('Error syncing reps: $e');
      throw e;
    }
  }

  Future<List<Rep>> getAllLocalReps() async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query('reps');
      return results.map((map) => Rep.fromMap(map)).toList();
    } catch (e) {
      print('Error getting all local reps: $e');
      return [];
    }
  }

  // Get Local Data
  Future<Profile?> getLocalUserProfile(String userId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'profiles',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (results.isNotEmpty) {
        return Profile.fromMap(results.first);
      }
      return null;
    } catch (e) {
      print('Error getting local user profile: $e');
      return null;
    }
  }

  Future<List<Profile>> getAllLocalProfiles() async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query('profiles');
      return results.map((map) => Profile.fromMap(map)).toList();
    } catch (e) {
      print('Error getting all local profiles: $e');
      return [];
    }
  }

  Future<List<Outlet>> fetchAllLocalOutlets() async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query('outlets');
      return results.map((map) => Outlet.fromMap(map)).toList();
    } catch (e) {
      print('Error getting all local outlets: $e');
      return [];
    }
  }

  Future<List<Product>> getAllLocalProducts() async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query('products');
      return results.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      print('Error getting all local products: $e');
      return [];
    }
  }

  // Sync All Data
  Future<Map<String, Map<String, int>>> syncAll() async {
    Map<String, Map<String, int>> syncResults = {};

    try {
      // Process any pending sync queue operations first (including deletions)
      await processSyncQueue();

      // Sync user and outlet data
      await syncProfilesToLocalDb();
      
      // Sync outlets both ways - first push local outlets to cloud, then pull from cloud
      final outletsSyncedToCloud = await syncOutletsToCloud();
      syncResults['outlets'] = await syncOutletsToLocalDb();
      syncResults['outlets']!['uploaded_to_cloud'] = outletsSyncedToCloud;
      
      syncResults['reps'] = await syncRepsToLocalDb();
      await syncCustomersToLocalDb();

      // Sync product data with proper transaction handling
      syncResults['products'] = await syncProductsToLocalDb();

      // Sync sales data with proper transaction handling
      syncResults['sales'] = await syncSalesToLocalDb();

      // Sync stock-related data
      syncResults['stock_balances'] = await syncStockBalancesToLocalDb();

      // Sync product distributions with error handling for missing table
      try {
        await syncProductDistributionsFromServer();
        await syncProductDistributionsToServer();
      } catch (e) {
        if (e.toString().contains(
            'relation "public.product_distributions" does not exist')) {
          print(
              'Warning: product_distributions table does not exist in cloud database. Skipping sync.');
          print(
              'Please run the migration: supabase/migrations/20240101000000_create_product_distributions_table.sql');
        } else {
          print('Error syncing product distributions: $e');
          // Re-throw other errors
          rethrow;
        }
      }

      // Sync stock intake data
      syncResults['stock_intake'] = await syncStockIntakesToLocalDb();

      // Sync intake balances
      syncResults['intake_balances'] = await syncIntakeBalancesToLocalDb();

      // Sync expenditures data
      syncResults['expenditures'] = await syncExpendituresToLocalDb();

      // Process any remaining sync queue operations after all syncs
      await processSyncQueue();

      return syncResults;
    } catch (e) {
      print('Error in syncAll: $e');
      throw e;
    }
  }

  // Customers Sync
  Future<void> syncCustomersToLocalDb() async {
    try {
      final db = await _dbHelper.database;

      // First sync local changes to cloud in a transaction
      await db.transaction((txn) async {
        final unsyncedCustomers = await txn.query(
          'customers',
          where: 'is_synced = ?',
          whereArgs: [0],
        );

        // Push unsynced customers to Supabase
        for (var customerMap in unsyncedCustomers) {
          await supabase.from('customers').upsert({
            'id': customerMap['id'],
            'full_name': customerMap['full_name'],
            'phone': customerMap['phone'],
            'outlet_id': customerMap['outlet_id'],
            'total_outstanding': customerMap['total_outstanding'],
            'created_at': customerMap['created_at'],
          });

          // Mark as synced locally
          await txn.update(
            'customers',
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [customerMap['id']],
          );
        }
      });

      // Pull latest customers from Supabase
      final response = await supabase.from('customers').select();
      final customers = response as List<dynamic>;

      // Update local database
      await db.transaction((txn) async {
        for (var customerData in customers) {
          await txn.insert(
              'customers',
              {
                'id': customerData['id'],
                'full_name': customerData['full_name'],
                'phone': customerData['phone'],
                'outlet_id': customerData['outlet_id'],
                'total_outstanding': customerData['total_outstanding'],
                'created_at': customerData['created_at'],
                'is_synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (e) {
      print('Error syncing customers: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getAllLocalCustomers() async {
    try {
      final db = await _dbHelper.database;
      return await db.query('customers');
    } catch (e) {
      print('Error getting all local customers: $e');
      return [];
    }
  }

  Future<bool> isOnline() async {
    try {
      await supabase.from('customers').select().limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> markForSync(
    String table,
    String id, {
    bool isDelete = false,
  }) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
          'sync_queue',
          {
            'table_name': table,
            'record_id': id,
            'is_delete': isDelete ? 1 : 0,
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('Error marking for sync: $e');
      throw e;
    }
  }

  Future<void> processSyncQueue() async {
    if (!await isOnline()) return;

    try {
      final db = await _dbHelper.database;
      final queue = await db.query('sync_queue');

      for (var item in queue) {
        final table = item['table_name'] as String;
        final recordId = item['record_id'] as String;
        final isDelete = item['is_delete'] == 1;
        bool shouldRemoveFromQueue = true;

        try {
          if (isDelete) {
            await supabase.from(table).delete().eq('id', recordId);
          } else {
            final record = await db.query(
              table,
              where: 'id = ?',
              whereArgs: [recordId],
              limit: 1,
            );

            if (record.isNotEmpty) {
              await supabase.from(table).upsert(record.first);
            }
          }
        } catch (e) {
          print('Error processing sync queue item $table:$recordId: $e');

          // Handle foreign key constraint violations for product deletions
          if (isDelete &&
              table == 'products' &&
              e.toString().contains('violates foreign key constraint')) {
            print(
                'Cannot delete product $recordId from server due to foreign key constraints. Skipping this sync operation.');
            // Remove from queue since this deletion cannot be completed
            shouldRemoveFromQueue = true;
          } else {
            // For other errors, don't remove from queue so it can be retried later
            shouldRemoveFromQueue = false;
            print('Keeping sync queue item $table:$recordId for retry later');
          }
        }

        // Only remove from queue if operation succeeded or if it's a foreign key constraint that can't be resolved
        if (shouldRemoveFromQueue) {
          await db.delete(
            'sync_queue',
            where: 'table_name = ? AND record_id = ?',
            whereArgs: [table, recordId],
          );
        }
      }
    } catch (e) {
      print('Error processing sync queue: $e');
      throw e;
    }
  }

  Future<Map<String, int>> syncStockBalancesToLocalDb() async {
    try {
      final db = await _dbHelper.database;
      int uploadedCount = 0;
      int downloadedCount = 0;

      // First sync local changes to cloud in a transaction
      await db.transaction((txn) async {
        final unsyncedBalances = await txn.query(
          'stock_balances',
          where: 'synced = ?',
          whereArgs: [0],
        );

        // Push unsynced balances to Supabase
        for (var balanceMap in unsyncedBalances) {
          await supabase.from('stock_balances').upsert({
            'id': balanceMap['id'],
            'outlet_id': balanceMap['outlet_id'],
            'product_id': balanceMap['product_id'],
            'given_quantity': balanceMap['given_quantity'],
            'sold_quantity': balanceMap['sold_quantity'],
            'balance_quantity': balanceMap['balance_quantity'],
            'last_updated': balanceMap['last_updated'],
            'created_at': balanceMap['created_at']
          });

          // Mark as synced locally
          await txn.update(
            'stock_balances',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [balanceMap['id']],
          );
          uploadedCount++;
        }
      });

      // Pull latest balances from Supabase
      final response = await supabase.from('stock_balances').select();
      final stockBalances = response as List<dynamic>;

      // Update local database in a separate transaction
      await db.transaction((txn) async {
        // Create stock_balances table if it doesn't exist
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS stock_balances (
            id TEXT PRIMARY KEY,
            outlet_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            given_quantity REAL NOT NULL,
            sold_quantity REAL DEFAULT 0,
            balance_quantity REAL NOT NULL,
            last_updated TEXT,
            created_at TEXT,
            synced INTEGER DEFAULT 1
          )
        ''');

        // Clear existing stock balances
        await txn.delete('stock_balances');

        // Insert new stock balances with foreign key validation
        for (var stockData in stockBalances) {
          final outletId = stockData['outlet_id'];
          final productId = stockData['product_id'];
          
          // Validate that outlet exists
          final outletExists = await txn.query(
            'outlets',
            where: 'id = ?',
            whereArgs: [outletId],
          );
          
          // Validate that product exists
          final productExists = await txn.query(
            'products',
            where: 'id = ?',
            whereArgs: [productId],
          );
          
          if (outletExists.isEmpty) {
            print('Warning: Skipping stock balance ${stockData['id']} - outlet $outletId does not exist in local database');
            continue;
          }
          
          if (productExists.isEmpty) {
            print('Warning: Skipping stock balance ${stockData['id']} - product $productId does not exist in local database');
            continue;
          }
          
          // Insert only if both foreign keys are valid
          await txn.insert(
              'stock_balances',
              {
                'id': stockData['id'],
                'outlet_id': outletId,
                'product_id': productId,
                'given_quantity': stockData['given_quantity'],
                'sold_quantity': stockData['sold_quantity'] ?? 0,
                'balance_quantity': stockData['balance_quantity'],
                'last_updated': stockData['last_updated'],
                'created_at': stockData['created_at'],
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
          downloadedCount++;
        }
      });

      return {
        'synced': uploadedCount + downloadedCount,
        'uploaded': uploadedCount,
        'downloaded': downloadedCount
      };
    } catch (e) {
      print('Error syncing stock balances: $e');
      throw e;
    }
  }

  // Migration for product units
  Future<void> migrateProductUnits() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> products = await db.query('products');

      await db.transaction((txn) async {
        for (var product in products) {
          if (product['unit'] == 'KG') {
            await txn.update(
              'products',
              {'unit': 'Kg'},
              where: 'id = ?',
              whereArgs: [product['id']],
            );
          }
        }
      });
    } catch (e) {
      print('Error migrating product units: $e');
      throw e;
    }
  }

  // Stock Intake Sync
  Future<bool> syncStockIntakeToSupabase(dynamic stockIntake) async {
    try {
      // Use upsert instead of insert to handle duplicates gracefully
      await supabase.from('stock_intake').upsert({
        'id': stockIntake.id,
        'product_name': stockIntake.productName,
        'quantity_received': stockIntake.quantityReceived,
        'unit': stockIntake.unit,
        'cost_per_unit': stockIntake.costPerUnit,
        'total_cost': stockIntake.totalCost,
        'description': stockIntake.description,
        'date_received': stockIntake.dateReceived.toIso8601String(),
        'created_at': stockIntake.createdAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error syncing stock intake to Supabase: $e');
      return false;
    }
  }

  Future<void> syncIntakeBalancesToSupabase(dynamic intakeBalance) async {
    try {
      // Check if balance already exists in cloud by product_name to prevent duplicates
      final existingResponse = await supabase
          .from('intake_balances')
          .select('id')
          .eq('product_name', intakeBalance.productName)
          .maybeSingle();

      if (existingResponse != null) {
        // Update existing record instead of creating duplicate
        await supabase.from('intake_balances').update({
          'total_received': intakeBalance.totalReceived,
          'total_assigned': intakeBalance.totalAssigned,
          'balance_quantity': intakeBalance.balanceQuantity,
          'last_updated': intakeBalance.lastUpdated.toIso8601String(),
        }).eq('product_name', intakeBalance.productName);
      } else {
        // Insert new record only if it doesn't exist
        await supabase.from('intake_balances').insert({
          'id': intakeBalance.id,
          'product_name': intakeBalance.productName,
          'total_received': intakeBalance.totalReceived,
          'total_assigned': intakeBalance.totalAssigned,
          'balance_quantity': intakeBalance.balanceQuantity,
          'last_updated': intakeBalance.lastUpdated.toIso8601String(),
        });
      }
    } catch (e) {
      // If the table doesn't exist, provide instructions for creating it
      if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        print(
          'Error: The intake_balances table does not exist in your Supabase project.',
        );
        print(
          'Please create it manually through the Supabase dashboard with the following schema:',
        );
        print('''
        CREATE TABLE public.intake_balances (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          product_name TEXT NOT NULL UNIQUE,
          total_received NUMERIC NOT NULL,
          total_assigned NUMERIC NOT NULL,
          balance_quantity NUMERIC NOT NULL,
          last_updated TIMESTAMP DEFAULT now()
        );
        ''');
      } else {
        print('Error syncing intake balances to Supabase: $e');
      }
      // Don't throw the error, just log it to prevent app crashes
    }
  }

  Future<Map<String, int>> syncIntakeBalancesToLocalDb() async {
    try {
      final db = await _dbHelper.database;

      // First sync local changes to cloud
      await db.transaction((txn) async {
        final unsyncedBalances = await txn.query(
          'intake_balances',
          where: 'is_synced = ?',
          whereArgs: [0],
        );

        // Push unsynced balances to Supabase with proper deduplication
        for (var balanceMap in unsyncedBalances) {
          final balance = IntakeBalance.fromMap(balanceMap);
          try {
            // Check if balance already exists in cloud by product_name
            final existingResponse = await supabase
                .from('intake_balances')
                .select('id')
                .eq('product_name', balance.productName)
                .maybeSingle();

            if (existingResponse != null) {
              // Update existing record
              await supabase.from('intake_balances').update({
                'total_received': balance.totalReceived,
                'total_assigned': balance.totalAssigned,
                'balance_quantity': balance.balanceQuantity,
                'last_updated': balance.lastUpdated.toIso8601String(),
              }).eq('product_name', balance.productName);
            } else {
              // Insert new record
              await supabase.from('intake_balances').insert({
                'id': balance.id,
                'product_name': balance.productName,
                'total_received': balance.totalReceived,
                'total_assigned': balance.totalAssigned,
                'balance_quantity': balance.balanceQuantity,
                'last_updated': balance.lastUpdated.toIso8601String(),
              });
            }

            // Mark as synced locally
            await txn.update(
              'intake_balances',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [balance.id],
            );
          } catch (uploadError) {
            print('Error uploading balance ${balance.id}: $uploadError');
            // Continue with other balances even if one fails
          }
        }
      });

      // Pull latest balances from Supabase and merge with local data
      try {
        final response = await supabase.from('intake_balances').select();
        final cloudBalances = (response as List)
            .map((data) => IntakeBalance.fromMap(data))
            .toList();

        // Update local database - MERGE cloud data with locally calculated data
        await db.transaction((txn) async {
          // Get locally calculated balances
          final localCalculatedBalances =
              await _getCalculatedBalancesFromLocal(txn);

          // Clear existing balances to prevent duplicates
          await txn.delete('intake_balances');

          // Use locally calculated data as the source of truth, but preserve cloud sync status
          final Map<String, IntakeBalance> cloudBalanceMap = {
            for (var balance in cloudBalances) balance.productName: balance
          };

          for (var localBalance in localCalculatedBalances) {
            final cloudBalance = cloudBalanceMap[localBalance.productName];
            await txn.insert(
              'intake_balances',
              {
                ...localBalance.toMap(),
                'is_synced': cloudBalance != null ? 1 : 0,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });

        print('Successfully synced intake balances with local calculations');
      } catch (downloadError) {
        print(
            'Error downloading intake balances from Supabase: $downloadError');
        // Fallback to local calculation if cloud sync fails
        await _recalculateIntakeBalancesFromLocalData();
      }

      // Count total synced records
      final balanceCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM intake_balances')) ??
          0;

      return {'synced': balanceCount, 'intake_balances': balanceCount};
    } catch (e) {
      print('Error syncing intake balances: $e');
      throw e;
    }
  }

  // Expenditures Sync
  Future<Map<String, int>> syncExpendituresToLocalDb() async {
    try {
      final db = await _dbHelper.database;
      int uploadedCount = 0;
      int downloadedCount = 0;

      // Get a valid outlet ID as fallback
      String? fallbackOutletId;
      try {
        final outlets = await getAllLocalOutlets();
        if (outlets.isNotEmpty) {
          fallbackOutletId = outlets.first.id;
        }
      } catch (e) {
        print('Warning: Could not get fallback outlet ID: $e');
      }

      // First sync local changes to cloud in a transaction
      await db.transaction((txn) async {
        final unsyncedExpenditures = await txn.query(
          'expenditures',
          where: 'is_synced = ?',
          whereArgs: [0],
        );

        // Push unsynced expenditures to Supabase
        for (var expenditureMap in unsyncedExpenditures) {
          // Helper function to validate UUID
          String? validateUuid(dynamic value) {
            if (value == null) return null;
            final str = value.toString();
            // Check if it's a valid UUID format
            final uuidRegex = RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                caseSensitive: false);
            return uuidRegex.hasMatch(str) ? str : null;
          }

          // Validate outlet_id and use fallback if invalid
          String? validatedOutletId = validateUuid(expenditureMap['outlet_id']);
          if (validatedOutletId == null && fallbackOutletId != null) {
            validatedOutletId = fallbackOutletId;
            print(
                'Warning: Invalid outlet_id "${expenditureMap['outlet_id']}" replaced with fallback: $fallbackOutletId');
          }

          // Skip this expenditure if we still don't have a valid outlet_id
          if (validatedOutletId == null) {
            print(
                'Error: Skipping expenditure ${expenditureMap['id']} - no valid outlet_id available');
            continue;
          }

          await supabase.from('expenditures').upsert({
            'id': expenditureMap['id'],
            'description': expenditureMap['description'],
            'amount': expenditureMap['amount'],
            'category': expenditureMap['category'],
            'outlet_id': validatedOutletId,
            'outlet_name': expenditureMap['outlet_name'], // Include outlet_name
            'payment_method': expenditureMap['payment_method'] ?? 'cash',
            'receipt_number': expenditureMap['receipt_number'],
            'vendor_name': expenditureMap['vendor_name'],
            'date_incurred': expenditureMap['date_incurred'],
            'status': expenditureMap['status'],
            'approved_by': validateUuid(expenditureMap['approved_by']),
            'rejected_by': validateUuid(expenditureMap['rejected_by']),
            'rejection_reason': expenditureMap['rejection_reason'],
            'notes': expenditureMap['notes'],
            'is_recurring': (expenditureMap['is_recurring'] == true ||
                    expenditureMap['is_recurring'] == 1)
                ? 1
                : 0,
            'recurring_frequency': expenditureMap['recurring_frequency'],
            'next_due_date': expenditureMap['next_due_date'],
            'created_at': expenditureMap['created_at'],
            'updated_at': expenditureMap['updated_at'],
          });

          // Mark as synced locally
          await txn.update(
            'expenditures',
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [expenditureMap['id']],
          );
          uploadedCount++;
        }
      });

      // Pull latest expenditures from Supabase
      final response = await supabase.from('expenditures').select();
      final expenditures = response as List<dynamic>;

      // Update local database
      await db.transaction((txn) async {
        for (var expenditureData in expenditures) {
          // Get outlet_name if missing from cloud data
          String? outletName = expenditureData['outlet_name'];
          if (outletName == null && expenditureData['outlet_id'] != null) {
            outletName = await getOutletName(expenditureData['outlet_id']);
          }

          await txn.insert(
            'expenditures',
            {
              'id': expenditureData['id'],
              'description': expenditureData['description'],
              'amount': expenditureData['amount'],
              'category': expenditureData['category'],
              'outlet_id': expenditureData['outlet_id'],
              'outlet_name': outletName ?? 'Unknown Outlet', // Provide fallback
              'payment_method': expenditureData['payment_method'] ??
                  'cash', // Provide default
              'receipt_number': expenditureData['receipt_number'],
              'vendor_name': expenditureData['vendor_name'],
              'date_incurred': expenditureData['date_incurred'],
              'status': expenditureData['status'],
              'approved_by': expenditureData['approved_by'],
              'rejected_by': expenditureData['rejected_by'],
              'rejection_reason': expenditureData['rejection_reason'],
              'notes': expenditureData['notes'],
              'is_recurring': (expenditureData['is_recurring'] == true ||
                      expenditureData['is_recurring'] == 1)
                  ? 1
                  : 0,
              'recurring_frequency': expenditureData['recurring_frequency'],
              'next_due_date': expenditureData['next_due_date'],
              'created_at': expenditureData['created_at'],
              'updated_at': expenditureData['updated_at'],
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          downloadedCount++;
        }
      });

      return {
        'synced': uploadedCount + downloadedCount,
        'uploaded': uploadedCount,
        'downloaded': downloadedCount
      };
    } catch (e) {
      if (e.toString().contains('null value in column "outlet_name"') ||
          e.toString().contains(
              'column "outlet_name" of relation "expenditures" does not exist')) {
        print(
            'Warning: expenditures table is missing outlet_name column in cloud database.');
        print(
            'Please run the migration: fix_missing_tables.sql to add the missing column.');
        print('Skipping expenditures sync for now.');
        return {'synced': 0, 'uploaded': 0, 'downloaded': 0};
      } else {
        print('Error syncing expenditures: $e');
        throw e;
      }
    }
  }

  Future<Map<String, int>> syncStockIntakesToLocalDb() async {
    try {
      // Process sync queue before main sync operations
      await processSyncQueue();

      final db = await _dbHelper.database;

      // First sync local changes to cloud in a transaction
      await db.transaction((txn) async {
        final unsyncedIntakes = await txn.query(
          'stock_intake',
          where: 'is_synced = ?',
          whereArgs: [0],
        );

        // Push unsynced intakes to Supabase
        for (var intakeMap in unsyncedIntakes) {
          final intake = StockIntake.fromMap(intakeMap);
          try {
            // Create a map without the is_synced field for Supabase
            final cloudMap = {
              'id': intake.id,
              'product_name': intake.productName,
              'quantity_received': intake.quantityReceived,
              'unit': intake.unit,
              'cost_per_unit': intake.costPerUnit,
              'total_cost': intake.totalCost,
              'description': intake.description,
              'date_received': intake.dateReceived.toIso8601String(),
              'created_at': intake.createdAt.toIso8601String(),
            };
            await supabase.from('stock_intake').upsert(cloudMap);
            // Mark as synced locally
            await txn.update(
              'stock_intake',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [intake.id],
            );
          } catch (uploadError) {
            print('Error uploading intake ${intake.id}: $uploadError');
            // Continue with other intakes even if one fails
          }
        }
      });

      // Pull latest intakes from Supabase
      try {
        final response = await supabase.from('stock_intake').select();
        final intakes = (response as List)
            .map((data) => StockIntake.fromMap(data))
            .toList();

        // Update local database in a transaction - MERGE instead of CLEAR
        await db.transaction((txn) async {
          // Insert or update intakes from cloud
          for (var intake in intakes) {
            await txn.insert(
              'stock_intake',
              {
                ...intake.toMap(),
                'is_synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });

        print(
            'Successfully synced ${intakes.length} stock intakes from Supabase');
      } catch (downloadError) {
        print('Error downloading stock intakes from Supabase: $downloadError');
        if (downloadError
            .toString()
            .contains('relation "public.stock_intake" does not exist')) {
          print(
              'The stock_intake table does not exist in Supabase. Please run the migration file: 20240301000000_create_stock_intake_tables.sql');
        }
      }

      // Recalculate intake balances from local data instead of syncing from cloud
      // This ensures local assignments are preserved
      try {
        await _recalculateIntakeBalancesFromLocalData();
        print('Successfully recalculated intake balances from local data');
      } catch (balanceError) {
        print('Error recalculating intake balances: $balanceError');
      }

      // Process sync queue after main sync operations
      await processSyncQueue();

      // Count total synced records
      final intakeCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM stock_intake')) ??
          0;

      return {'synced': intakeCount, 'stock_intake': intakeCount};
    } catch (e) {
      print('Error syncing stock intakes: $e');
      throw e;
    }
  }

  Future<void> syncStockIntakesFromSupabase() async {
    try {
      final response = await supabase.from('stock_intake').select();
      final stockIntakes = response as List<dynamic>;

      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // Create table if it doesn't exist
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS stock_intake (
            id TEXT PRIMARY KEY,
            product_name TEXT NOT NULL,
            quantity_received REAL NOT NULL,
            unit TEXT NOT NULL,
            cost_per_unit REAL NOT NULL,
            total_cost REAL NOT NULL,
            description TEXT,
            date_received TEXT NOT NULL,
            created_at TEXT NOT NULL,
            is_synced INTEGER DEFAULT 1
          )
        ''');

        // Insert stock intakes
        for (final intakeData in stockIntakes) {
          await txn.insert(
              'stock_intake',
              {
                'id': intakeData['id'] as String? ?? '',
                'product_name': intakeData['product_name'] as String? ?? '',
                'quantity_received':
                    (intakeData['quantity_received'] as num?)?.toDouble() ??
                        0.0,
                'unit': intakeData['unit'] as String? ?? '',
                'cost_per_unit':
                    (intakeData['cost_per_unit'] as num?)?.toDouble() ?? 0.0,
                'total_cost':
                    (intakeData['total_cost'] as num?)?.toDouble() ?? 0.0,
                'description': intakeData['description'] as String?,
                'date_received': intakeData['date_received'] as String? ??
                    DateTime.now().toIso8601String(),
                'created_at': intakeData['created_at'] as String? ??
                    DateTime.now().toIso8601String(),
                'is_synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (e) {
      print('Error syncing stock intakes from Supabase: $e');
      throw e;
    }
  }

  // Recalculate intake balances from local stock_intake and products data
  // Helper method to get calculated balances from local data without modifying the database
  Future<List<IntakeBalance>> _getCalculatedBalancesFromLocal(
      DatabaseExecutor txn) async {
    // Calculate total received per product from stock_intake
    final receivedQuery = await txn.rawQuery('''
      SELECT 
        product_name,
        SUM(quantity_received) as total_received
      FROM stock_intake
      GROUP BY product_name
    ''');

    // Calculate total assigned per product from product_distributions table
    // This ensures we only count actual distributions, not just product assignments
    final assignedQuery = await txn.rawQuery('''
      SELECT 
        product_name,
        SUM(quantity) as total_assigned
      FROM product_distributions
      GROUP BY product_name
    ''');

    // Create a map of assigned quantities
    final Map<String, double> assignedQuantities = {};
    for (var row in assignedQuery) {
      final productName = row['product_name'] as String;
      final totalAssigned = (row['total_assigned'] as num?)?.toDouble() ?? 0.0;
      assignedQuantities[productName] = totalAssigned;
    }

    // Create intake balance records
    final List<IntakeBalance> balances = [];
    for (var row in receivedQuery) {
      final productName = row['product_name'] as String;
      final totalReceived = (row['total_received'] as num?)?.toDouble() ?? 0.0;
      final totalAssigned = assignedQuantities[productName] ?? 0.0;
      final balanceQuantity = totalReceived - totalAssigned;

      final balance = IntakeBalance(
        id: const Uuid().v4(),
        productName: productName,
        totalReceived: totalReceived,
        totalAssigned: totalAssigned,
        balanceQuantity: balanceQuantity,
        lastUpdated: DateTime.now(),
        isSynced: false,
      );

      balances.add(balance);
    }

    return balances;
  }

  Future<void> _recalculateIntakeBalancesFromLocalData() async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // Create table if it doesn't exist
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS intake_balances (
          id TEXT PRIMARY KEY,
          product_name TEXT NOT NULL,
          total_received REAL NOT NULL,
          total_assigned REAL DEFAULT 0,
          balance_quantity REAL NOT NULL,
          last_updated TEXT NOT NULL,
          is_synced INTEGER DEFAULT 0
        )
      ''');

      // Clear existing balances to prevent duplicates
      await txn.delete('intake_balances');

      // Get calculated balances and insert them
      final balances = await _getCalculatedBalancesFromLocal(txn);
      for (var balance in balances) {
        await txn.insert(
          'intake_balances',
          balance.toMap(),
        );
      }
    });
  }

  // Utility method to clean up duplicate intake balance records in Supabase
  Future<void> cleanupDuplicateIntakeBalances() async {
    try {
      print('Starting cleanup of duplicate intake balance records...');

      // Get all records from Supabase
      final response = await supabase.from('intake_balances').select();
      final allRecords = response as List<dynamic>;

      if (allRecords.isEmpty) {
        print('No records found to clean up.');
        return;
      }

      // Group records by product_name
      final Map<String, List<dynamic>> groupedRecords = {};
      for (var record in allRecords) {
        final productName = record['product_name'] as String;
        if (!groupedRecords.containsKey(productName)) {
          groupedRecords[productName] = [];
        }
        groupedRecords[productName]!.add(record);
      }

      int duplicatesRemoved = 0;

      // For each product, keep only the most recent record and delete the rest
      for (var entry in groupedRecords.entries) {
        final productName = entry.key;
        final records = entry.value;

        if (records.length > 1) {
          // Sort by last_updated (most recent first)
          records.sort((a, b) {
            final aTime = DateTime.parse(a['last_updated']);
            final bTime = DateTime.parse(b['last_updated']);
            return bTime.compareTo(aTime);
          });

          // Keep the first (most recent) record, delete the rest
          final recordsToDelete = records.skip(1).toList();

          for (var recordToDelete in recordsToDelete) {
            await supabase
                .from('intake_balances')
                .delete()
                .eq('id', recordToDelete['id']);
            duplicatesRemoved++;
          }

          print(
              'Cleaned up ${recordsToDelete.length} duplicate records for product: $productName');
        }
      }

      print('Cleanup completed. Removed $duplicatesRemoved duplicate records.');
      print('Remaining unique products: ${groupedRecords.length}');
    } catch (e) {
      print('Error during cleanup: $e');
      throw e;
    }
  }

  @override
  void dispose() {
    // Clean up resources if needed
  }
}
