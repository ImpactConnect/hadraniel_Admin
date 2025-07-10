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
    // TODO: Add sync methods for sales, customers, and stock balances
  }
}
