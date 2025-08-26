import 'dart:io';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart';
import '../database/database_helper.dart';
import 'sync_service.dart';

/// Enhanced sync service with atomic transactions, retry mechanism, and backup functionality
class EnhancedSyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _originalSyncService = SyncService();

  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const String backupSuffix = '_backup';

  /// Creates a backup of the database before performing sync operations
  Future<String> createDatabaseBackup() async {
    try {
      final db = await _dbHelper.database;
      final dbPath = db.path;
      final backupPath =
          '${dbPath}${backupSuffix}_${DateTime.now().millisecondsSinceEpoch}.db';

      // Close the database temporarily to create a clean backup
      await db.close();

      // Copy the database file
      final originalFile = File(dbPath);
      if (await originalFile.exists()) {
        await originalFile.copy(backupPath);
        print('Database backup created: $backupPath');
      }

      // Reopen the database
      await _dbHelper.database;

      return backupPath;
    } catch (e) {
      print('Error creating database backup: $e');
      rethrow;
    }
  }

  /// Restores database from backup
  Future<void> restoreDatabaseFromBackup(String backupPath) async {
    try {
      final db = await _dbHelper.database;
      final dbPath = db.path;

      // Close the current database
      await db.close();

      // Restore from backup
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.copy(dbPath);
        print('Database restored from backup: $backupPath');
      } else {
        throw Exception('Backup file not found: $backupPath');
      }

      // Reopen the database
      await _dbHelper.database;
    } catch (e) {
      print('Error restoring database from backup: $e');
      rethrow;
    }
  }

  /// Cleans up old backup files (keeps only the last 5 backups)
  Future<void> cleanupOldBackups() async {
    try {
      final db = await _dbHelper.database;
      final dbPath = db.path;
      final dbDirectory = Directory(dirname(dbPath));

      if (await dbDirectory.exists()) {
        final backupFiles = await dbDirectory
            .list()
            .where((file) => file.path.contains(backupSuffix))
            .cast<File>()
            .toList();

        // Sort by modification time (newest first)
        backupFiles.sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        // Keep only the last 5 backups
        if (backupFiles.length > 5) {
          for (int i = 5; i < backupFiles.length; i++) {
            await backupFiles[i].delete();
            print('Deleted old backup: ${backupFiles[i].path}');
          }
        }
      }
    } catch (e) {
      print('Error cleaning up old backups: $e');
    }
  }

  /// Enhanced sync queue processing with retry mechanism
  Future<void> processSyncQueueWithRetry() async {
    final db = await _dbHelper.database;

    try {
      // Get items that haven't reached max retry attempts
      final queue = await db.query('sync_queue',
          where: 'failed_attempts < ? OR failed_attempts IS NULL',
          whereArgs: [maxRetryAttempts],
          orderBy: 'created_at ASC');

      for (var item in queue) {
        final table = item['table_name'] as String;
        final recordId = item['record_id'] as String;
        final isDelete = item['is_delete'] == 1;
        final queueId = item['id'] as int;
        final currentAttempts = (item['failed_attempts'] as int?) ?? 0;

        // Skip if already at max attempts
        if (currentAttempts >= maxRetryAttempts) {
          continue;
        }

        try {
          await _processSingleQueueItem(table, recordId, isDelete);

          // Remove from queue on success
          await db.delete(
            'sync_queue',
            where: 'id = ?',
            whereArgs: [queueId],
          );

          print(
              'Successfully synced $table:$recordId on attempt ${currentAttempts + 1}');
        } catch (e) {
          final newAttempts = currentAttempts + 1;
          print('Attempt $newAttempts failed for $table:$recordId: $e');

          if (newAttempts >= maxRetryAttempts) {
            // Mark as failed after max attempts
            await _markQueueItemAsFailed(queueId, e.toString());
            print('Max retry attempts reached for $table:$recordId');
          } else {
            // Update retry count and timestamp
            await db.update(
              'sync_queue',
              {
                'failed_attempts': newAttempts,
                'last_retry_at': DateTime.now().toIso8601String(),
                'error_message': e.toString(),
              },
              where: 'id = ?',
              whereArgs: [queueId],
            );

            // Exponential backoff delay
            await Future.delayed(retryDelay * newAttempts);
          }
        }
      }
    } catch (e) {
      print('Error processing sync queue: $e');
      rethrow;
    }
  }

  /// Process a single queue item
  Future<void> _processSingleQueueItem(
      String table, String recordId, bool isDelete) async {
    final supabase = Supabase.instance.client;

    if (isDelete) {
      await supabase.from(table).delete().eq('id', recordId);
    } else {
      final db = await _dbHelper.database;
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
  }

  /// Mark a queue item as failed
  Future<void> _markQueueItemAsFailed(int queueId, String errorMessage) async {
    final db = await _dbHelper.database;

    await db.update(
      'sync_queue',
      {
        'failed_attempts': maxRetryAttempts,
        'error_message': errorMessage,
        'last_retry_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  /// Enhanced sales sync with atomic transactions and backup
  Future<void> syncSalesToLocalDbEnhanced() async {
    String? backupPath;

    try {
      // Create backup before sync
      backupPath = await createDatabaseBackup();

      final db = await _dbHelper.database;
      final supabase = Supabase.instance.client;

      // Use a single atomic transaction for the entire sales sync operation
      await db.transaction((txn) async {
        try {
          // Step 1: Push unsynced local sales to cloud
          final unsyncedSales = await txn.query(
            'sales',
            where: 'is_synced = ?',
            whereArgs: [0],
          );

          for (var saleMap in unsyncedSales) {
            // Push sale to cloud
            await supabase.from('sales').upsert(saleMap);

            // Push associated sale items
            final saleItems = await txn.query(
              'sale_items',
              where: 'sale_id = ? AND is_synced = ?',
              whereArgs: [saleMap['id'], 0],
            );

            for (var itemMap in saleItems) {
              await supabase.from('sale_items').upsert(itemMap);

              // Mark sale item as synced
              await txn.update(
                'sale_items',
                {'is_synced': 1},
                where: 'id = ?',
                whereArgs: [itemMap['id']],
              );
            }

            // Mark sale as synced
            await txn.update(
              'sales',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [saleMap['id']],
            );
          }

          // Step 2: Pull latest sales from cloud
          final salesResponse = await supabase.from('sales').select();
          final sales = salesResponse as List<dynamic>;

          final saleItemsResponse = await supabase.from('sale_items').select();
          final saleItems = saleItemsResponse as List<dynamic>;

          // Step 3: Clear and repopulate local data
          await txn.delete('sale_items');
          await txn.delete('sales');

          // Insert sales
          for (final saleData in sales) {
            await txn.insert(
              'sales',
              {...(saleData as Map<String, dynamic>), 'is_synced': 1},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          // Insert sale items
          for (final itemData in saleItems) {
            await txn.insert(
              'sale_items',
              {...(itemData as Map<String, dynamic>), 'is_synced': 1},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          print(
              'Successfully synced ${sales.length} sales and ${saleItems.length} sale items');
        } catch (e) {
          print('Error in sales sync transaction: $e');
          // Transaction will automatically rollback
          rethrow;
        }
      });

      // Clean up old backups on successful sync
      await cleanupOldBackups();
    } catch (e) {
      print('Sales sync failed: $e');

      // Restore from backup if available
      if (backupPath != null) {
        try {
          await restoreDatabaseFromBackup(backupPath);
          print('Database restored from backup due to sync failure');
        } catch (restoreError) {
          print('Failed to restore from backup: $restoreError');
        }
      }

      rethrow;
    }
  }

  /// Enhanced products sync with atomic transactions and backup
  Future<void> syncProductsToLocalDbEnhanced() async {
    String? backupPath;

    try {
      // Create backup before sync
      backupPath = await createDatabaseBackup();

      final db = await _dbHelper.database;
      final supabase = Supabase.instance.client;

      // Use atomic transaction for the entire products sync operation
      await db.transaction((txn) async {
        try {
          // Step 1: Push unsynced local products to cloud
          final unsyncedProducts = await txn.query(
            'products',
            where: 'is_synced = ?',
            whereArgs: [0],
          );

          for (var productMap in unsyncedProducts) {
            await supabase.from('products').upsert(productMap);

            // Mark as synced
            await txn.update(
              'products',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [productMap['id']],
            );
          }

          // Step 2: Pull latest products from cloud
          final response = await supabase.from('products').select();
          final products = response as List<dynamic>;

          // Step 3: Update local products
          for (final productData in products) {
            await txn.insert(
              'products',
              {...(productData as Map<String, dynamic>), 'is_synced': 1},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          print('Successfully synced ${products.length} products');
        } catch (e) {
          print('Error in products sync transaction: $e');
          rethrow;
        }
      });

      // Clean up old backups on successful sync
      await cleanupOldBackups();
    } catch (e) {
      print('Products sync failed: $e');

      // Restore from backup if available
      if (backupPath != null) {
        try {
          await restoreDatabaseFromBackup(backupPath);
          print('Database restored from backup due to sync failure');
        } catch (restoreError) {
          print('Failed to restore from backup: $restoreError');
        }
      }

      rethrow;
    }
  }

  /// Enhanced sync all with comprehensive error handling and backup
  Future<void> syncAllEnhanced() async {
    String? backupPath;

    try {
      // Create backup before starting sync
      backupPath = await createDatabaseBackup();

      // Process sync queue with retry mechanism first
      await processSyncQueueWithRetry();

      // Sync core data with enhanced methods
      await _originalSyncService.syncProfilesToLocalDb();
      await _originalSyncService.syncOutletsToLocalDb();
      await _originalSyncService.syncRepsToLocalDb();
      await _originalSyncService.syncCustomersToLocalDb();

      // Use enhanced sync methods for critical data
      await syncProductsToLocalDbEnhanced();
      await syncSalesToLocalDbEnhanced();

      // Sync other data with original methods
      await _originalSyncService.syncStockBalancesToLocalDb();
      await _originalSyncService.syncStockIntakesToLocalDb();
      await _originalSyncService.syncExpendituresToLocalDb();

      // Process any remaining sync queue operations
      await processSyncQueueWithRetry();

      // Clean up old backups on successful sync
      await cleanupOldBackups();

      print('Enhanced sync completed successfully');
    } catch (e) {
      print('Enhanced sync failed: $e');

      // Restore from backup if available
      if (backupPath != null) {
        try {
          await restoreDatabaseFromBackup(backupPath);
          print('Database restored from backup due to sync failure');
        } catch (restoreError) {
          print('Failed to restore from backup: $restoreError');
        }
      }

      rethrow;
    }
  }

  /// Get failed sync queue items for manual retry
  Future<List<Map<String, dynamic>>> getFailedSyncItems() async {
    final db = await _dbHelper.database;

    try {
      return await db.query(
        'sync_queue',
        where: 'failed_attempts >= ?',
        whereArgs: [maxRetryAttempts],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      print('Error getting failed sync items: $e');
      return [];
    }
  }

  /// Get sync queue statistics
  Future<Map<String, int>> getSyncQueueStats() async {
    final db = await _dbHelper.database;

    final totalResult =
        await db.rawQuery('SELECT COUNT(*) as count FROM sync_queue');
    final failedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue WHERE failed_attempts >= ?',
        [maxRetryAttempts]);
    final pendingResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue WHERE failed_attempts < ? OR failed_attempts IS NULL',
        [maxRetryAttempts]);

    return {
      'total': totalResult.first['count'] as int,
      'failed': failedResult.first['count'] as int,
      'pending': pendingResult.first['count'] as int,
    };
  }

  /// Retry specific failed sync item by ID
  Future<bool> retryFailedSyncItem(int queueId) async {
    final db = await _dbHelper.database;

    try {
      // Get the item details
      final items = await db.query(
        'sync_queue',
        where: 'id = ?',
        whereArgs: [queueId],
        limit: 1,
      );

      if (items.isEmpty) {
        return false;
      }

      final item = items.first;
      final table = item['table_name'] as String;
      final recordId = item['record_id'] as String;
      final isDelete = item['is_delete'] == 1;

      // Try to process the item
      await _processSingleQueueItem(table, recordId, isDelete);

      // Remove from queue on success
      await db.delete(
        'sync_queue',
        where: 'id = ?',
        whereArgs: [queueId],
      );

      print('Successfully retried and synced $table:$recordId');
      return true;
    } catch (e) {
      print('Failed to retry sync item $queueId: $e');

      // Update error message
      await db.update(
        'sync_queue',
        {
          'error_message': e.toString(),
          'last_retry_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [queueId],
      );

      return false;
    }
  }

  /// Retry all failed sync items (reset their failed attempts)
  Future<void> retryAllFailedSyncItems() async {
    final db = await _dbHelper.database;

    try {
      await db.update(
        'sync_queue',
        {
          'failed_attempts': 0,
          'error_message': null,
          'last_retry_at': null,
        },
        where: 'failed_attempts >= ?',
        whereArgs: [maxRetryAttempts],
      );

      print('Reset all failed sync items for retry');

      // Process the queue again
      await processSyncQueueWithRetry();
    } catch (e) {
      print('Error retrying failed sync items: $e');
      rethrow;
    }
  }

  /// Clear failed sync items from queue
  Future<void> clearFailedSyncItems() async {
    final db = await _dbHelper.database;

    try {
      final deletedCount = await db.delete(
        'sync_queue',
        where: 'failed_attempts >= ?',
        whereArgs: [maxRetryAttempts],
      );
      print('Cleared $deletedCount failed sync items from queue');
    } catch (e) {
      print('Error clearing failed sync items: $e');
      rethrow;
    }
  }

  /// Clear all sync queue items (use with caution)
  Future<void> clearAllSyncQueue() async {
    final db = await _dbHelper.database;
    final deletedCount = await db.delete('sync_queue');
    print('Cleared all $deletedCount items from sync queue');
  }
}
