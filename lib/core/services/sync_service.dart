import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../models/outlet_model.dart';
import '../models/product_model.dart';
import '../models/rep_model.dart';
import '../models/sale_model.dart';
import '../database/database_helper.dart';

class SyncService {
  // Sales methods
  Future<List<Sale>> getAllLocalSales() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('sales');
    return List.generate(maps.length, (i) => Sale.fromMap(maps[i]));
  }

  Future<void> syncSalesToLocalDb() async {
    try {
      final response = await supabase.from('sales').select();
      final sales = response as List<dynamic>;

      final db = await _dbHelper.database;
      final batch = db.batch();

      // Clear existing sales
      batch.delete('sales');

      // Insert new sales
      for (final saleData in sales) {
        batch.insert(
          'sales',
          Sale.fromMap(saleData as Map<String, dynamic>).toMap(),
        );
      }

      await batch.commit();
    } catch (e) {
      print('Error syncing sales: $e');
      rethrow;
    }
  }

  final supabase = Supabase.instance.client;
  final DatabaseHelper _dbHelper = DatabaseHelper();

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
    } catch (e) {
      print('Error inserting product: $e');
      throw e;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );
    } catch (e) {
      print('Error updating product: $e');
      throw e;
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('products', where: 'id = ?', whereArgs: [productId]);
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

  Future<String> getOutletName(String outletId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'outlets',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [outletId],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return results.first['name'] as String;
      }
      return 'Unknown Outlet';
    } catch (e) {
      print('Error getting outlet name: $e');
      return 'Error';
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
        await supabase.from('products').upsert(product.toMap());

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

      // Update local database
      await db.transaction((txn) async {
        for (var product in products) {
          await txn.insert('products', {
            ...product.toMap(),
            'is_synced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
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

  @override
  void dispose() {
    // Clean up resources if needed
  }
}
