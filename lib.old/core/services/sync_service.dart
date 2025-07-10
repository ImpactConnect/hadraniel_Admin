import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../models/outlet_model.dart';
import '../models/product_model.dart';
import '../models/rep_model.dart';
import '../database/database_helper.dart';

class SyncService {
  final supabase = Supabase.instance.client;
  final DatabaseHelper _dbHelper = DatabaseHelper();

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
  Future<void> syncOutletsToLocalDb() async {
    try {
      final response = await supabase.from('outlets').select();
      final outlets = (response as List)
          .map((data) => Outlet.fromMap(data))
          .toList();

      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        for (var outlet in outlets) {
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

  // Products Sync
  Future<void> syncProductsToLocalDb() async {
    try {
      final response = await supabase.from('products').select();
      final products = (response as List)
          .map((data) => Product.fromMap(data))
          .toList();

      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        for (var product in products) {
          await txn.insert(
            'products',
            product.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
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

  Future<List<Outlet>> getAllLocalOutlets() async {
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
