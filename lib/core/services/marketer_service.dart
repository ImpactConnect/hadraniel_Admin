import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/marketer_model.dart';
import '../models/marketer_target_model.dart';
import '../database/database_helper.dart';

class MarketerService {
  final supabase = Supabase.instance.client;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final bool _cloudDisabled = true;

  Future<void> _verifyMarketerTables() async {
    try {
      await supabase.from('marketers').select().limit(1);
      await supabase.from('marketer_targets').select().limit(1);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('404') || msg.contains('Not Found')) {
        print(
            'Marketer tables missing or inaccessible. See supabase/migrations/20250103000000_create_marketer_tables.sql');
        throw Exception(
            'Cloud tables not found: marketers/marketer_targets. Please run migration supabase/migrations/20250103000000_create_marketer_tables.sql in Supabase SQL or use `supabase db push`.');
      }
      rethrow;
    }
  }

  // MARKETER CRUD OPERATIONS

  Future<void> addMarketerLocally(Marketer marketer) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'marketers',
        marketer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error adding marketer locally: $e');
      throw e;
    }
  }

  Future<List<Marketer>> getAllMarketers() async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query('marketers', orderBy: 'created_at DESC');
      return results.map((map) => Marketer.fromMap(map)).toList();
    } catch (e) {
      print('Error getting all marketers: $e');
      return [];
    }
  }

  Future<List<Marketer>> getMarketersByOutlet(String outletId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'marketers',
        where: 'outlet_id = ?',
        whereArgs: [outletId],
        orderBy: 'created_at DESC',
      );
      return results.map((map) => Marketer.fromMap(map)).toList();
    } catch (e) {
      print('Error getting marketers by outlet: $e');
      return [];
    }
  }

  Future<Marketer?> getMarketerById(String id) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'marketers',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return Marketer.fromMap(results.first);
      }
      return null;
    } catch (e) {
      print('Error getting marketer by id: $e');
      return null;
    }
  }

  Future<Marketer> createMarketer({
    required String fullName,
    required String email,
    String? phone,
    required String outletId,
  }) async {
    try {
      final marketer = Marketer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fullName: fullName,
        email: email,
        phone: phone,
        outletId: outletId,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add to local database first
      await addMarketerLocally(marketer);

      // Cloud disabled for offline-only mode
      if (!_cloudDisabled) {
        await syncMarketerToCloud(marketer);
      }

      return marketer;
    } catch (e) {
      print('Error creating marketer: $e');
      throw e;
    }
  }

  Future<bool> updateMarketer(Marketer marketer) async {
    try {
      final updatedMarketer = marketer.copyWith(
        updatedAt: DateTime.now(),
      );

      // Update locally
      await addMarketerLocally(updatedMarketer);

      // Cloud disabled for offline-only mode
      if (!_cloudDisabled) {
        await syncMarketerToCloud(updatedMarketer);
      }

      return true;
    } catch (e) {
      print('Error updating marketer: $e');
      return false;
    }
  }

  Future<bool> deleteMarketer(String id) async {
    try {
      // Cloud disabled for offline-only mode
      if (!_cloudDisabled) {
        await supabase.from('marketers').delete().eq('id', id);
      }

      // Delete from local database
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // Delete marketer targets first (foreign key constraint)
        await txn.delete('marketer_targets',
            where: 'marketer_id = ?', whereArgs: [id]);
        // Delete marketer
        await txn.delete('marketers', where: 'id = ?', whereArgs: [id]);
      });

      return true;
    } catch (e) {
      print('Error deleting marketer: $e');
      return false;
    }
  }

  // MARKETER TARGET CRUD OPERATIONS

  Future<void> addMarketerTargetLocally(MarketerTarget target) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'marketer_targets',
        target.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error adding marketer target locally: $e');
      throw e;
    }
  }

  Future<List<MarketerTarget>> getMarketerTargets(String marketerId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'marketer_targets',
        where: 'marketer_id = ?',
        whereArgs: [marketerId],
        orderBy: 'created_at DESC',
      );
      return results.map((map) => MarketerTarget.fromMap(map)).toList();
    } catch (e) {
      print('Error getting marketer targets: $e');
      return [];
    }
  }

  Future<List<MarketerTarget>> getActiveTargets(String marketerId) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      final results = await db.query(
        'marketer_targets',
        where: 'marketer_id = ? AND status = ? AND end_date > ?',
        whereArgs: [marketerId, 'active', now],
        orderBy: 'created_at DESC',
      );
      return results.map((map) => MarketerTarget.fromMap(map)).toList();
    } catch (e) {
      print('Error getting active targets: $e');
      return [];
    }
  }

  Future<MarketerTarget> createMarketerTarget({
    required String marketerId,
    required String productId,
    required String outletId,
    double? targetQuantity,
    double? targetRevenue,
    required String targetType,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final target = MarketerTarget(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        marketerId: marketerId,
        productId: productId,
        outletId: outletId,
        targetQuantity: targetQuantity,
        targetRevenue: targetRevenue,
        targetType: targetType,
        startDate: startDate,
        endDate: endDate,
        currentQuantity: 0.0,
        currentRevenue: 0.0,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add to local database first
      await addMarketerTargetLocally(target);

      // Cloud disabled for offline-only mode
      if (!_cloudDisabled) {
        await syncMarketerTargetToCloud(target);
      }

      return target;
    } catch (e) {
      print('Error creating marketer target: $e');
      throw e;
    }
  }

  Future<bool> updateMarketerTarget(MarketerTarget target) async {
    try {
      final updatedTarget = target.copyWith(
        updatedAt: DateTime.now(),
      );

      // Update locally
      await addMarketerTargetLocally(updatedTarget);

      // Cloud disabled for offline-only mode
      if (!_cloudDisabled) {
        await syncMarketerTargetToCloud(updatedTarget);
      }

      return true;
    } catch (e) {
      print('Error updating marketer target: $e');
      return false;
    }
  }

  Future<bool> deleteMarketerTarget(String id) async {
    try {
      // Cloud disabled for offline-only mode
      if (!_cloudDisabled) {
        await supabase.from('marketer_targets').delete().eq('id', id);
      }

      // Delete from local database
      final db = await _dbHelper.database;
      await db.delete('marketer_targets', where: 'id = ?', whereArgs: [id]);

      return true;
    } catch (e) {
      print('Error deleting marketer target: $e');
      return false;
    }
  }

  // SALES TRACKING AND PROGRESS UPDATE

  Future<void> updateTargetProgress(
      String targetId, double soldQuantity, double soldRevenue) async {
    try {
      final db = await _dbHelper.database;

      // Get current target
      final results = await db.query(
        'marketer_targets',
        where: 'id = ?',
        whereArgs: [targetId],
        limit: 1,
      );

      if (results.isEmpty) return;

      final target = MarketerTarget.fromMap(results.first);

      // Update progress
      final updatedTarget = target.copyWith(
        currentQuantity: target.currentQuantity + soldQuantity,
        currentRevenue: target.currentRevenue + soldRevenue,
        updatedAt: DateTime.now(),
      );

      // Check if target is completed
      String newStatus = target.status;
      if (target.isQuantityTarget &&
          updatedTarget.currentQuantity >= (target.targetQuantity ?? 0)) {
        newStatus = 'completed';
      } else if (target.isRevenueTarget &&
          updatedTarget.currentRevenue >= (target.targetRevenue ?? 0)) {
        newStatus = 'completed';
      }

      final finalTarget = updatedTarget.copyWith(status: newStatus);

      await updateMarketerTarget(finalTarget);
    } catch (e) {
      print('Error updating target progress: $e');
      throw e;
    }
  }

  /// Process all sales and update marketer target progress
  /// This should be called after sales are synced from the cloud
  Future<void> processSalesForTargetUpdates() async {
    try {
      final db = await _dbHelper.database;

      // Get all active marketer targets
      final targetResults = await db.query(
        'marketer_targets',
        where: 'status = ? AND start_date <= ? AND end_date >= ?',
        whereArgs: [
          'active',
          DateTime.now().toIso8601String(),
          DateTime.now().toIso8601String(),
        ],
      );

      if (targetResults.isEmpty) {
        print('No active targets found for processing');
        return;
      }

      final targets =
          targetResults.map((map) => MarketerTarget.fromMap(map)).toList();
      print('Processing ${targets.length} active targets');

      // Reset all target progress to recalculate from scratch
      for (final target in targets) {
        await db.update(
          'marketer_targets',
          {
            'current_quantity': 0,
            'current_revenue': 0.0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [target.id],
        );
      }

      // Process each target
      for (final target in targets) {
        await _processTargetSales(target);
      }

      print('Completed processing sales for target updates');
    } catch (e) {
      print('Error processing sales for target updates: $e');
      throw e;
    }
  }

  /// Process sales for a specific target and update progress
  Future<void> _processTargetSales(MarketerTarget target) async {
    try {
      final db = await _dbHelper.database;

      // Get all sales for the target's product within the target period
      final salesResults = await db.rawQuery('''
        SELECT s.*, si.quantity, si.unit_price, si.total_price
        FROM sales s
        INNER JOIN sale_items si ON s.id = si.sale_id
        INNER JOIN marketers m ON s.outlet_id = m.outlet_id
        WHERE si.product_id = ? 
          AND m.id = ?
          AND s.created_at >= ? 
          AND s.created_at <= ?
        ORDER BY s.created_at DESC
      ''', [
        target.productId,
        target.marketerId,
        target.startDate.toIso8601String(),
        target.endDate.toIso8601String(),
      ]);

      if (salesResults.isEmpty) {
        print('No sales found for target ${target.id}');
        return;
      }

      // Calculate totals
      double totalQuantity = 0;
      double totalRevenue = 0;

      for (final saleData in salesResults) {
        final quantity = (saleData['quantity'] as num?)?.toDouble() ?? 0.0;
        final revenue = (saleData['total_price'] as num?)?.toDouble() ?? 0.0;

        totalQuantity += quantity;
        totalRevenue += revenue;
      }

      print(
          'Target ${target.id}: Found ${salesResults.length} sales, Total Qty: $totalQuantity, Total Revenue: $totalRevenue');

      // Update target progress
      String newStatus = target.status;
      if (target.isQuantityTarget &&
          totalQuantity >= (target.targetQuantity ?? 0)) {
        newStatus = 'completed';
      } else if (target.isRevenueTarget &&
          totalRevenue >= (target.targetRevenue ?? 0)) {
        newStatus = 'completed';
      }

      await db.update(
        'marketer_targets',
        {
          'current_quantity': totalQuantity.round(),
          'current_revenue': totalRevenue,
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [target.id],
      );

      print(
          'Updated target ${target.id} progress: Qty: $totalQuantity, Revenue: $totalRevenue, Status: $newStatus');
    } catch (e) {
      print('Error processing target ${target.id}: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> getMarketerPerformance(String marketerId) async {
    try {
      final targets = await getMarketerTargets(marketerId);

      int totalTargets = targets.length;
      int completedTargets = targets.where((t) => t.isCompleted).length;
      int activeTargets = targets.where((t) => t.isActive).length;
      int expiredTargets = targets.where((t) => t.isExpired).length;

      double totalTargetRevenue =
          targets.fold(0.0, (sum, t) => sum + (t.targetRevenue ?? 0));
      double totalCurrentRevenue =
          targets.fold(0.0, (sum, t) => sum + t.currentRevenue);

      double totalTargetQuantity =
          targets.fold(0.0, (sum, t) => sum + (t.targetQuantity ?? 0));
      double totalCurrentQuantity =
          targets.fold(0.0, (sum, t) => sum + t.currentQuantity);

      double overallRevenueProgress = totalTargetRevenue > 0
          ? (totalCurrentRevenue / totalTargetRevenue) * 100
          : 0.0;

      double overallQuantityProgress = totalTargetQuantity > 0
          ? (totalCurrentQuantity / totalTargetQuantity) * 100
          : 0.0;

      return {
        'totalTargets': totalTargets,
        'completedTargets': completedTargets,
        'activeTargets': activeTargets,
        'expiredTargets': expiredTargets,
        'completionRate':
            totalTargets > 0 ? (completedTargets / totalTargets) * 100 : 0.0,
        'totalTargetRevenue': totalTargetRevenue,
        'totalCurrentRevenue': totalCurrentRevenue,
        'totalTargetQuantity': totalTargetQuantity,
        'totalCurrentQuantity': totalCurrentQuantity,
        'overallRevenueProgress': overallRevenueProgress,
        'overallQuantityProgress': overallQuantityProgress,
      };
    } catch (e) {
      print('Error getting marketer performance: $e');
      return {};
    }
  }

  // CLOUD SYNC OPERATIONS

  Future<void> syncMarketerToCloud(Marketer marketer) async {
    try {
      if (_cloudDisabled) {
        return;
      }
      await _verifyMarketerTables();
      // Check if user is authenticated
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception(
            'User not authenticated. Please login to sync marketers to cloud.');
      }

      // Check if marketers table exists and user has access
      final response =
          await supabase.from('marketers').upsert(marketer.toCloudMap());
      print('Successfully synced marketer ${marketer.id} to cloud');
    } catch (e) {
      print('Error syncing marketer to cloud: $e');

      // Provide more specific error messages
      if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        throw Exception(
            'Marketers table not found in database. Please ensure the migration has been applied.');
      } else if (e.toString().contains('401') ||
          e.toString().contains('Unauthorized')) {
        throw Exception(
            'Authentication required. Please login to save marketers.');
      } else if (e.toString().contains('403') ||
          e.toString().contains('Forbidden')) {
        throw Exception(
            'Access denied. Admin privileges required to save marketers.');
      }

      throw e;
    }
  }

  Future<void> syncMarketerTargetToCloud(MarketerTarget target) async {
    try {
      if (_cloudDisabled) {
        return;
      }
      await _verifyMarketerTables();
      await supabase.from('marketer_targets').upsert(target.toCloudMap());
    } catch (e) {
      print('Error syncing marketer target to cloud: $e');
      throw e;
    }
  }

  Future<void> syncMarketersToCloud() async {
    try {
      if (_cloudDisabled) {
        return;
      }
      final marketers = await getAllMarketers();
      for (var marketer in marketers) {
        await syncMarketerToCloud(marketer);
      }
    } catch (e) {
      print('Error syncing marketers to cloud: $e');
      throw e;
    }
  }

  Future<void> fetchMarketersFromCloud() async {
    try {
      if (_cloudDisabled) {
        return;
      }
      await _verifyMarketerTables();
      final response = await supabase.from('marketers').select();
      final marketers =
          (response as List).map((data) => Marketer.fromMap(data)).toList();

      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // Clear existing marketers
        await txn.delete('marketers');
        // Insert new marketers
        for (var marketer in marketers) {
          await txn.insert(
            'marketers',
            marketer.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      print('Error fetching marketers from cloud: $e');
      throw e;
    }
  }

  Future<void> fetchMarketerTargetsFromCloud() async {
    try {
      if (_cloudDisabled) {
        return;
      }
      await _verifyMarketerTables();
      final response = await supabase.from('marketer_targets').select();
      final targets = (response as List)
          .map((data) => MarketerTarget.fromMap(data))
          .toList();

      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // Clear existing targets
        await txn.delete('marketer_targets');
        // Insert new targets
        for (var target in targets) {
          await txn.insert(
            'marketer_targets',
            target.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      print('Error fetching marketer targets from cloud: $e');
      throw e;
    }
  }

  Future<void> fullSync() async {
    try {
      if (_cloudDisabled) {
        return;
      }
      await syncMarketersToCloud();
      await fetchMarketersFromCloud();
      await fetchMarketerTargetsFromCloud();
    } catch (e) {
      print('Error in full sync: $e');
      throw e;
    }
  }

  // Method to get all marketer targets (for analytics)
  Future<List<MarketerTarget>> getAllMarketerTargets() async {
    try {
      final db = await _dbHelper.database;
      final results =
          await db.query('marketer_targets', orderBy: 'created_at DESC');
      return results.map((map) => MarketerTarget.fromMap(map)).toList();
    } catch (e) {
      print('Error getting all marketer targets: $e');
      return [];
    }
  }
}