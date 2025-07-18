import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../models/outlet_model.dart';
import '../models/product_model.dart';
import '../models/rep_model.dart';
import '../models/sale_model.dart';
import '../models/sale_item_model.dart';
import '../models/product_distribution_model.dart';
import '../database/database_helper.dart';
import 'stock_intake_service.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Cache for outlet names to avoid repeated database queries
  final Map<String, String> _outletNameCache = {};
  final Map<String, Outlet> _outletCache = {};

  // Cache for customer names
  final Map<String, String> _customerNameCache = {};

  // Cache for rep names
  final Map<String, String> _repNameCache = {};

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

    String query = '''
      SELECT s.* FROM sales s
      WHERE 1=1
    ''';

    List<dynamic> args = [];

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

    // Add product filter if provided - this requires joining with sale_items
    if (productId != null) {
      query = '''
        SELECT DISTINCT s.* FROM sales s
        INNER JOIN sale_items si ON s.id = si.sale_id
        WHERE si.product_id = ?
      ''';

      // Reset args and add product ID as first argument
      args = [productId];

      // Re-add other filters
      if (startDate != null) {
        query += ' AND s.created_at >= ?';
        args.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        query += ' AND s.created_at <= ?';
        args.add(endDate.toIso8601String());
      }

      if (outletId != null) {
        query += ' AND s.outlet_id = ?';
        args.add(outletId);
      }

      if (repId != null) {
        query += ' AND s.rep_id = ?';
        args.add(repId);
      }
    }

    query += ' ORDER BY s.created_at DESC';

    final List<Map<String, dynamic>> sales = await db.rawQuery(query, args);

    List<Map<String, dynamic>> salesWithDetails = [];

    for (var sale in sales) {
      final saleId = sale['id'] as String;
      final saleOutletId = sale['outlet_id'] as String;
      final customerId = sale['customer_id'] as String?;
      final saleRepId = sale['rep_id'] as String?;

      // Get outlet name
      String outletName = await getOutletName(saleOutletId);

      // Get customer name if customer_id is not null
      String customerName = '';
      if (customerId != null) {
        customerName = await getCustomerName(customerId);
      }

      // Get rep name if rep_id is not null
      String repName = '';
      if (saleRepId != null) {
        repName = await getRepName(saleRepId);
      }

      // Get sale items
      final saleItems = await getSaleItems(saleId);
      final itemCount = saleItems.length;

      salesWithDetails.add({
        ...sale,
        'outlet_name': outletName,
        'customer_name': customerName,
        'rep_name': repName,
        'item_count': itemCount,
      });
    }

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
      SELECT si.*, p.product_name 
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

  Future<void> syncSalesToLocalDb() async {
    try {
      print('Syncing sales from cloud database...');
      print('Supabase client: ${supabase != null ? 'initialized' : 'null'}');
      print('Supabase URL: ${supabase.supabaseUrl}');
      print(
        'Supabase auth: ${supabase.auth.currentSession != null ? 'authenticated' : 'not authenticated'}',
      );

      final response = await supabase.from('sales').select();
      print('Raw response: $response');
      final sales = response as List<dynamic>;
      print('Found ${sales.length} sales in cloud database');

      final db = await _dbHelper.database;

      // First check if we have any sales in the local database
      final localCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM sales'),
      );
      print('Local sales count: $localCount');

      // Only clear and re-insert if we have data to sync or if local DB is empty
      if (sales.isNotEmpty || localCount == 0) {
        final batch = db.batch();

        // Clear existing sales and sale_items
        batch.delete('sale_items');
        batch.delete('sales');

        // Insert new sales
        for (final saleData in sales) {
          try {
            print('Processing sale: ${saleData['id']}');
            final sale = Sale.fromMap(saleData as Map<String, dynamic>);
            print(
              'Mapped to Sale: ${sale.id}, outletId: ${sale.outletId}, totalAmount: ${sale.totalAmount}',
            );
            batch.insert('sales', sale.toMap());
          } catch (e) {
            print('Error processing sale ${saleData['id']}: $e');
            print('Raw sale data: $saleData');
          }
        }

        try {
          await batch.commit();
          print('Successfully synced ${sales.length} sales to local database');
        } catch (commitError) {
          print('Error committing sales batch: $commitError');
          rethrow;
        }

        // Now sync sale items for each sale
        await syncSaleItemsToLocalDb();
      } else {
        print('No sales to sync from cloud database');
        // Still try to sync sale items in case there are orphaned records
        await syncSaleItemsToLocalDb();
      }
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

      // First check if we have any sale items in the local database
      final localCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM sale_items'),
      );
      print('Local sale items count: $localCount');

      // Only clear and re-insert if we have data to sync or if local DB is empty
      if (saleItems.isNotEmpty || localCount == 0) {
        final batch = db.batch();

        // Clear existing sale items
        batch.delete('sale_items');

        // Insert new sale items
        for (final itemData in saleItems) {
          try {
            print('Processing sale item: ${itemData['id']}');
            final saleItem = SaleItem.fromMap(itemData as Map<String, dynamic>);
            print(
              'Mapped to SaleItem: ${saleItem.id}, saleId: ${saleItem.saleId}, productId: ${saleItem.productId}',
            );
            batch.insert('sale_items', saleItem.toMap());
          } catch (e) {
            print('Error processing sale item ${itemData['id']}: $e');
            print('Raw item data: $itemData');
          }
        }

        try {
          await batch.commit();
          print(
            'Successfully synced ${saleItems.length} sale items to local database',
          );
        } catch (commitError) {
          print('Error committing sale items batch: $commitError');
          rethrow;
        }
      } else {
        print('No sale items to sync from cloud database');
      }
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
      final profiles = (response as List)
          .map((data) => Profile.fromMap(data))
          .toList();

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
  Future<void> syncOutletsToLocalDb([List<Outlet>? outlets]) async {
    try {
      final outletsToSync =
          outlets ??
          (await supabase.from('outlets').select() as List)
              .map((data) => Outlet.fromMap(data))
              .toList();

      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        for (var outlet in outletsToSync) {
          await txn.insert(
            'outlets',
            outlet.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      print('Error syncing outlets: $e');
      throw e;
    }
  }

  // Products Management
  Future<void> insertProduct(Product product) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('products', product.toMap());

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

      // Get the previous product to calculate quantity difference
      final List<Map<String, dynamic>> previousProductMaps = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [product.id],
      );

      if (previousProductMaps.isNotEmpty) {
        final previousProduct = Product.fromMap(previousProductMaps.first);

        // Update the product in the database
        await db.update(
          'products',
          product.toMap(),
          where: 'id = ?',
          whereArgs: [product.id],
        );

        // Only update balance if the product name is the same
        if (previousProduct.productName == product.productName) {
          // Calculate the difference in quantity
          final quantityDifference =
              product.quantity - previousProduct.quantity;

          // Update balance
          final outletName = await getOutletName(product.outletId);
          final stockIntakeService = StockIntakeService();
          await stockIntakeService.updateBalanceOnProductAssignment(
            product.productName,
            quantityDifference,
            product.outletId,
            outletName,
            product.costPerUnit,
          );
        } else {
          // If product name changed, treat it as a new assignment
          final stockIntakeService = StockIntakeService();
          final outletName = await getOutletName(product.outletId);
          await stockIntakeService.updateBalanceOnProductAssignment(
            product.productName,
            product.quantity,
            product.outletId,
            outletName,
            product.costPerUnit,
          );
        }
      } else {
        // If product doesn't exist (shouldn't happen), just update
        await db.update(
          'products',
          product.toMap(),
          where: 'id = ?',
          whereArgs: [product.id],
        );
      }
    } catch (e) {
      print('Error updating product: $e');
      throw e;
    }
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

        // Delete the product
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
      } else {
        // If product doesn't exist, just try to delete
        await db.delete('products', where: 'id = ?', whereArgs: [productId]);
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
      final List<Map<String, dynamic>> maps = await db.query(
        'product_distributions',
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      final distributions = maps
          .map((map) => ProductDistribution.fromMap(map))
          .toList();

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
          'distribution_date': distribution.distributionDate.toIso8601String(),
          'created_at': distribution.createdAt.toIso8601String(),
        });

        // Mark as synced in local DB
        await db.update(
          'product_distributions',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [distribution.id],
        );
      }
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
      final localDistributions = localMaps
          .map((map) => ProductDistribution.fromMap(map))
          .toList();

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
  Future<void> syncProductsToLocalDb() async {
    try {
      // Get all local products that need syncing
      final db = await _dbHelper.database;
      final unsyncedProducts = await db.query(
        'products',
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      // Push unsynced products to Supabase
      for (var productMap in unsyncedProducts) {
        final product = Product.fromMap(productMap);
        await supabase.from('products').upsert(product.toCloudMap());

        // Mark as synced locally
        await db.update(
          'products',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [product.id],
        );
      }

      // Pull latest products from Supabase
      final response = await supabase.from('products').select();
      print('Supabase products response: $response');

      final products = (response as List).map((data) {
        print('Processing product data: $data');
        try {
          return Product.fromMap(data);
        } catch (e) {
          print('Error processing product: $data');
          print('Error details: $e');
          rethrow;
        }
      }).toList();

      // Get existing products to compare quantities
      final List<Map<String, dynamic>> existingProductsMaps = await db.query(
        'products',
      );
      final Map<String, Product> existingProducts = {};
      for (var map in existingProductsMaps) {
        final product = Product.fromMap(map);
        existingProducts[product.id] = product;
      }

      final stockIntakeService = StockIntakeService();

      // Update local database
      await db.transaction((txn) async {
        for (var product in products) {
          // Check if product exists and quantity has changed
          if (existingProducts.containsKey(product.id)) {
            final existingProduct = existingProducts[product.id]!;

            // If product name is the same and quantity has changed
            if (existingProduct.productName == product.productName &&
                existingProduct.quantity != product.quantity) {
              // Calculate quantity difference
              final quantityDifference =
                  product.quantity - existingProduct.quantity;

              // Update balance
              final outletName = await getOutletName(product.outletId);
              await stockIntakeService.updateBalanceOnProductAssignment(
                product.productName,
                quantityDifference,
                product.outletId,
                outletName,
                product.costPerUnit,
              );
            }
            // If product name has changed, treat as deletion of old and addition of new
            else if (existingProduct.productName != product.productName) {
              // Remove old product quantity from balance
              final existingOutletName = await getOutletName(
                existingProduct.outletId,
              );
              await stockIntakeService.updateBalanceOnProductAssignment(
                existingProduct.productName,
                -existingProduct.quantity,
                existingProduct.outletId,
                existingOutletName,
                existingProduct.costPerUnit,
              );

              // Add new product quantity to balance
              final outletName = await getOutletName(product.outletId);
              await stockIntakeService.updateBalanceOnProductAssignment(
                product.productName,
                product.quantity,
                product.outletId,
                outletName,
                product.costPerUnit,
              );
            }
          }
          // New product, add its quantity to balance
          else {
            final outletName = await getOutletName(product.outletId);
            await stockIntakeService.updateBalanceOnProductAssignment(
              product.productName,
              product.quantity,
              product.outletId,
              outletName,
              product.costPerUnit,
            );
          }

          // Insert or update the product
          await txn.insert('products', {
            ...product.toMap(),
            'is_synced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Handle deleted products (products that exist locally but not in the server response)
        for (var existingProduct in existingProducts.values) {
          if (!products.any((p) => p.id == existingProduct.id)) {
            // Product was deleted on server, remove its quantity from balance
            final existingOutletName = await getOutletName(
              existingProduct.outletId,
            );
            await stockIntakeService.updateBalanceOnProductAssignment(
              existingProduct.productName,
              -existingProduct.quantity,
              existingProduct.outletId,
              existingOutletName,
              existingProduct.costPerUnit,
            );

            // Delete the product locally
            await txn.delete(
              'products',
              where: 'id = ?',
              whereArgs: [existingProduct.id],
            );
          }
        }
      });
    } catch (e) {
      print('Error syncing products: $e');
      throw e;
    }
  }

  // Reps Sync
  Future<void> syncRepsToLocalDb() async {
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('role', 'rep');
      final reps = (response as List).map((data) => Rep.fromMap(data)).toList();

      final db = await _dbHelper.database;
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
        }
      });
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
  Future<void> syncAll() async {
    await syncProfilesToLocalDb();
    await syncOutletsToLocalDb();
    await syncProductsToLocalDb();
    await syncRepsToLocalDb();
    await syncCustomersToLocalDb();
    await syncSalesToLocalDb();
    await syncStockBalancesToLocalDb();
    await syncProductDistributionsFromServer();
    await syncProductDistributionsToServer();
  }

  // Customers Sync
  Future<void> syncCustomersToLocalDb() async {
    try {
      // Get all local customers that need syncing
      final db = await _dbHelper.database;
      final unsyncedCustomers = await db.query(
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
        await db.update(
          'customers',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [customerMap['id']],
        );
      }

      // Pull latest customers from Supabase
      final response = await supabase.from('customers').select();
      final customers = response as List<dynamic>;

      // Update local database
      await db.transaction((txn) async {
        for (var customerData in customers) {
          await txn.insert('customers', {
            'id': customerData['id'],
            'full_name': customerData['full_name'],
            'phone': customerData['phone'],
            'outlet_id': customerData['outlet_id'],
            'total_outstanding': customerData['total_outstanding'],
            'created_at': customerData['created_at'],
            'is_synced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
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
      await db.insert('sync_queue', {
        'table_name': table,
        'record_id': id,
        'is_delete': isDelete ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
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

        await db.delete(
          'sync_queue',
          where: 'table_name = ? AND record_id = ?',
          whereArgs: [table, recordId],
        );
      }
    } catch (e) {
      print('Error processing sync queue: $e');
      throw e;
    }
  }

  Future<void> syncStockBalancesToLocalDb() async {
    try {
      final response = await supabase.from('stock_balances').select();
      final stockBalances = response as List<dynamic>;

      final db = await _dbHelper.database;
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

        // Insert new stock balances
        for (var stockData in stockBalances) {
          await txn.insert('stock_balances', {
            'id': stockData['id'],
            'outlet_id': stockData['outlet_id'],
            'product_id': stockData['product_id'],
            'given_quantity': stockData['given_quantity'],
            'sold_quantity': stockData['sold_quantity'] ?? 0,
            'balance_quantity': stockData['balance_quantity'],
            'last_updated': stockData['last_updated'],
            'created_at': stockData['created_at'],
            'synced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
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
      await supabase.from('stock_intake').insert({
        'id': stockIntake.id,
        'product_name': stockIntake.productName,
        'quantity': stockIntake.quantityReceived,
        'unit': stockIntake.unit,
        'cost_per_unit': stockIntake.costPerUnit,
        // 'total_cost' is generated in the database
        'description': stockIntake.description,
        'received_date': stockIntake.dateReceived.toIso8601String(),
        // 'created_at' is generated in the database
      });
      return true;
    } catch (e) {
      print('Error syncing stock intake to Supabase: $e');
      return false;
    }
  }

  Future<void> syncIntakeBalancesToSupabase(dynamic intakeBalance) async {
    try {
      // Try to upsert the data
      await supabase.from('intake_balances').upsert({
        'id': intakeBalance.id,
        'product_name': intakeBalance.productName,
        'total_received': intakeBalance.totalReceived,
        'total_assigned': intakeBalance.totalAssigned,
        'balance_quantity': intakeBalance.balanceQuantity,
        'last_updated': intakeBalance.lastUpdated.toIso8601String(),
      });
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
          product_name TEXT NOT NULL,
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
          await txn.insert('stock_intake', {
            'id': intakeData['id'],
            'product_name': intakeData['product_name'],
            'quantity_received': intakeData['quantity_received'],
            'unit': intakeData['unit'],
            'cost_per_unit': intakeData['cost_per_unit'],
            'total_cost': intakeData['total_cost'],
            'description': intakeData['description'],
            'date_received': intakeData['date_received'],
            'created_at': intakeData['created_at'],
            'is_synced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (e) {
      print('Error syncing stock intakes from Supabase: $e');
      throw e;
    }
  }

  @override
  void dispose() {
    // Clean up resources if needed
  }
}
