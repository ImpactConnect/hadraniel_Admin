import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/sale_item_model.dart';
import 'sync_service.dart';

/// Optimized sync service with pagination, batch operations, and performance monitoring
class OptimizedSyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _originalSyncService = SyncService();

  // Performance configuration
  static const int DEFAULT_PAGE_SIZE = 1000;
  static const int BATCH_SIZE = 500;
  static const int MAX_RETRY_ATTEMPTS = 3;
  static const Duration RETRY_DELAY = Duration(seconds: 2);

  // Performance monitoring
  static final Map<String, List<Duration>> _queryTimes = {};
  static final Map<String, int> _operationCounts = {};

  /// Initialize database with performance optimizations
  Future<void> initializeOptimizedDatabase() async {
    final db = await _dbHelper.database;
    await _optimizeDatabase(db);
  }

  /// Apply database performance optimizations
  Future<void> _optimizeDatabase(Database db) async {
    try {
      // Enable WAL mode for better concurrency
      await db.execute('PRAGMA journal_mode=WAL');

      // Set synchronous mode to NORMAL for better performance
      await db.execute('PRAGMA synchronous=NORMAL');

      // Increase cache size to 10MB
      await db.execute('PRAGMA cache_size=10000');

      // Store temporary tables in memory
      await db.execute('PRAGMA temp_store=MEMORY');

      // Enable memory-mapped I/O (256MB)
      await db.execute('PRAGMA mmap_size=268435456');

      // Enable query planner optimizations
      await db.execute('PRAGMA optimize');

      // Analyze tables for better query planning
      await db.execute('ANALYZE');

      print('Database optimizations applied successfully');
    } catch (e) {
      print('Warning: Some database optimizations failed: $e');
    }
  }

  /// Measure query performance
  Future<T> _measureQuery<T>(
      String queryName, Future<T> Function() query) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await query();
      stopwatch.stop();

      // Track performance metrics
      _queryTimes.putIfAbsent(queryName, () => []).add(stopwatch.elapsed);
      _operationCounts[queryName] = (_operationCounts[queryName] ?? 0) + 1;

      // Log slow queries
      if (stopwatch.elapsedMilliseconds > 1000) {
        print('SLOW QUERY: $queryName took ${stopwatch.elapsedMilliseconds}ms');
      }

      return result;
    } catch (e) {
      stopwatch.stop();
      print(
          'QUERY ERROR: $queryName failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }

  /// Optimized products sync with pagination and batch operations
  Future<Map<String, int>> syncProductsOptimized() async {
    return await _measureQuery('syncProductsOptimized', () async {
      int totalSynced = 0;
      int uploaded = 0;
      int downloaded = 0;

      final db = await _dbHelper.database;
      final supabase = Supabase.instance.client;

      await db.transaction((txn) async {
        // Step 1: Upload unsynced local products in batches
        final unsyncedProducts = await txn.query(
          'products',
          where: 'is_synced = ?',
          whereArgs: [0],
        );

        if (unsyncedProducts.isNotEmpty) {
          uploaded = await _batchUploadProducts(supabase, unsyncedProducts);

          // Mark as synced
          await _batchUpdateSyncStatus(txn, 'products',
              unsyncedProducts.map((p) => p['id'] as String).toList());
        }

        // Step 2: Download products with pagination
        downloaded = await _downloadProductsWithPagination(txn, supabase);

        totalSynced = uploaded + downloaded;
      });

      print(
          'Products sync completed: $totalSynced total ($uploaded uploaded, $downloaded downloaded)');
      return {
        'synced': totalSynced,
        'uploaded': uploaded,
        'downloaded': downloaded,
      };
    });
  }

  /// Download products with pagination to prevent memory overflow
  Future<int> _downloadProductsWithPagination(
      Transaction txn, SupabaseClient supabase) async {
    int totalDownloaded = 0;
    int offset = 0;
    bool hasMore = true;

    while (hasMore) {
      // Fetch page from Supabase
      final response = await supabase
          .from('products')
          .select()
          .range(offset, offset + DEFAULT_PAGE_SIZE - 1)
          .order('created_at');

      final products = response as List;
      hasMore = products.length == DEFAULT_PAGE_SIZE;

      if (products.isNotEmpty) {
        // Batch insert products
        await _batchInsertProducts(txn, products);
        totalDownloaded += products.length;

        print('Downloaded ${products.length} products (offset: $offset)');
      }

      offset += DEFAULT_PAGE_SIZE;
    }

    return totalDownloaded;
  }

  /// Batch insert products for better performance
  Future<void> _batchInsertProducts(
      Transaction txn, List<dynamic> products) async {
    final batch = txn.batch();

    for (var productData in products) {
      batch.insert(
        'products',
        {...(productData as Map<String, dynamic>), 'is_synced': 1},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Batch upload products to Supabase
  Future<int> _batchUploadProducts(
      SupabaseClient supabase, List<Map<String, dynamic>> products) async {
    int uploaded = 0;

    // Process in batches to avoid overwhelming the server
    for (int i = 0; i < products.length; i += BATCH_SIZE) {
      final batch = products.skip(i).take(BATCH_SIZE).toList();

      try {
        // Remove is_synced field for cloud upload
        final cloudBatch = batch.map((p) {
          final cloudProduct = Map<String, dynamic>.from(p);
          cloudProduct.remove('is_synced');
          return cloudProduct;
        }).toList();

        await supabase.from('products').upsert(cloudBatch);
        uploaded += batch.length;

        print('Uploaded ${batch.length} products to cloud');
      } catch (e) {
        print('Error uploading product batch: $e');
        // Continue with next batch
      }
    }

    return uploaded;
  }

  /// Batch update sync status for multiple records
  Future<void> _batchUpdateSyncStatus(
      Transaction txn, String table, List<String> ids) async {
    if (ids.isEmpty) return;

    // Use batch update for better performance
    final batch = txn.batch();

    for (var id in ids) {
      batch.update(
        table,
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    await batch.commit(noResult: true);
  }

  /// Optimized sales sync with enhanced batch processing
  Future<Map<String, int>> syncSalesOptimized() async {
    return await _measureQuery('syncSalesOptimized', () async {
      int totalSynced = 0;
      int uploaded = 0;
      int downloaded = 0;

      final db = await _dbHelper.database;
      final supabase = Supabase.instance.client;

      await db.transaction((txn) async {
        // Step 1: Upload unsynced sales and sale items
        final uploadResult = await _uploadUnsyncedSales(txn, supabase);
        uploaded = uploadResult['sales']! + uploadResult['saleItems']!;

        // Step 2: Download sales with pagination
        downloaded = await _downloadSalesWithPagination(txn, supabase);

        totalSynced = uploaded + downloaded;
      });

      print(
          'Sales sync completed: $totalSynced total ($uploaded uploaded, $downloaded downloaded)');
      return {
        'synced': totalSynced,
        'uploaded': uploaded,
        'downloaded': downloaded,
      };
    });
  }

  /// Upload unsynced sales and sale items in batches
  Future<Map<String, int>> _uploadUnsyncedSales(
      Transaction txn, SupabaseClient supabase) async {
    int salesUploaded = 0;
    int saleItemsUploaded = 0;

    // Upload sales
    final unsyncedSales = await txn.query(
      'sales',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    if (unsyncedSales.isNotEmpty) {
      salesUploaded = await _batchUploadSales(supabase, unsyncedSales);
      await _batchUpdateSyncStatus(
          txn, 'sales', unsyncedSales.map((s) => s['id'] as String).toList());
    }

    // Upload sale items
    final unsyncedSaleItems = await txn.query(
      'sale_items',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    if (unsyncedSaleItems.isNotEmpty) {
      saleItemsUploaded =
          await _batchUploadSaleItems(supabase, unsyncedSaleItems);
      await _batchUpdateSyncStatus(txn, 'sale_items',
          unsyncedSaleItems.map((si) => si['id'] as String).toList());
    }

    return {
      'sales': salesUploaded,
      'saleItems': saleItemsUploaded,
    };
  }

  /// Batch upload sales to Supabase
  Future<int> _batchUploadSales(
      SupabaseClient supabase, List<Map<String, dynamic>> sales) async {
    int uploaded = 0;

    for (int i = 0; i < sales.length; i += BATCH_SIZE) {
      final batch = sales.skip(i).take(BATCH_SIZE).toList();

      try {
        final cloudBatch = batch.map((s) {
          final cloudSale = Map<String, dynamic>.from(s);
          cloudSale.remove('is_synced');
          return cloudSale;
        }).toList();

        await supabase.from('sales').upsert(cloudBatch);
        uploaded += batch.length;
      } catch (e) {
        print('Error uploading sales batch: $e');
      }
    }

    return uploaded;
  }

  /// Batch upload sale items to Supabase
  Future<int> _batchUploadSaleItems(
      SupabaseClient supabase, List<Map<String, dynamic>> saleItems) async {
    int uploaded = 0;

    for (int i = 0; i < saleItems.length; i += BATCH_SIZE) {
      final batch = saleItems.skip(i).take(BATCH_SIZE).toList();

      try {
        final cloudBatch = batch.map((si) {
          final cloudSaleItem = Map<String, dynamic>.from(si);
          cloudSaleItem.remove('is_synced');
          return cloudSaleItem;
        }).toList();

        await supabase.from('sale_items').upsert(cloudBatch);
        uploaded += batch.length;
      } catch (e) {
        print('Error uploading sale items batch: $e');
      }
    }

    return uploaded;
  }

  /// Download sales with pagination
  Future<int> _downloadSalesWithPagination(
      Transaction txn, SupabaseClient supabase) async {
    int totalDownloaded = 0;

    // Download sales
    int salesDownloaded = await _downloadTableWithPagination(
        txn, supabase, 'sales', 'created_at');

    // Download sale items
    int saleItemsDownloaded = await _downloadTableWithPagination(
        txn, supabase, 'sale_items', 'created_at');

    totalDownloaded = salesDownloaded + saleItemsDownloaded;
    return totalDownloaded;
  }

  /// Generic method to download any table with pagination
  Future<int> _downloadTableWithPagination(Transaction txn,
      SupabaseClient supabase, String tableName, String orderBy) async {
    int totalDownloaded = 0;
    int offset = 0;
    bool hasMore = true;

    while (hasMore) {
      final response = await supabase
          .from(tableName)
          .select()
          .range(offset, offset + DEFAULT_PAGE_SIZE - 1)
          .order(orderBy);

      final records = response as List;
      hasMore = records.length == DEFAULT_PAGE_SIZE;

      if (records.isNotEmpty) {
        await _batchInsertRecords(txn, tableName, records);
        totalDownloaded += records.length;

        print(
            'Downloaded ${records.length} $tableName records (offset: $offset)');
      }

      offset += DEFAULT_PAGE_SIZE;
    }

    return totalDownloaded;
  }

  /// Generic batch insert for any table
  Future<void> _batchInsertRecords(
      Transaction txn, String tableName, List<dynamic> records) async {
    final batch = txn.batch();

    for (var recordData in records) {
      batch.insert(
        tableName,
        {...(recordData as Map<String, dynamic>), 'is_synced': 1},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Optimized sync queue processing with batch operations
  Future<void> processSyncQueueOptimized() async {
    return await _measureQuery('processSyncQueueOptimized', () async {
      final db = await _dbHelper.database;

      // Get all pending queue items
      final queue = await db.query(
        'sync_queue',
        where: 'failed_attempts < ? OR failed_attempts IS NULL',
        whereArgs: [MAX_RETRY_ATTEMPTS],
        orderBy: 'table_name, is_delete, created_at',
      );

      if (queue.isEmpty) {
        print('Sync queue is empty');
        return;
      }

      // Group items by table and operation type for batch processing
      final groupedItems = <String, List<Map<String, dynamic>>>{};

      for (var item in queue) {
        final key = '${item['table_name']}_${item['is_delete']}';
        groupedItems.putIfAbsent(key, () => []).add(item);
      }

      print(
          'Processing ${queue.length} sync queue items in ${groupedItems.length} groups');

      // Process each group
      for (var entry in groupedItems.entries) {
        await _processBatchedSyncItems(db, entry.value);
      }

      print('Sync queue processing completed');
    });
  }

  /// Process a batch of similar sync items
  Future<void> _processBatchedSyncItems(
      Database db, List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;

    final tableName = items.first['table_name'] as String;
    final isDelete = items.first['is_delete'] == 1;
    final supabase = Supabase.instance.client;

    print(
        'Processing ${items.length} ${isDelete ? 'delete' : 'upsert'} operations for $tableName');

    final successfulItems = <int>[];
    final failedItems = <Map<String, dynamic>>[];

    if (isDelete) {
      // Process deletes individually (can't batch delete by ID list easily)
      for (var item in items) {
        try {
          await supabase.from(tableName).delete().eq('id', item['record_id']);
          successfulItems.add(item['id'] as int);
        } catch (e) {
          failedItems.add({...item, 'error': e.toString()});
        }
      }
    } else {
      // Batch process upserts
      try {
        final recordIds =
            items.map((item) => item['record_id'] as String).toList();

        // Fetch all records in one query
        final records = await db.query(
          tableName,
          where: 'id IN (${recordIds.map((_) => '?').join(', ')})',
          whereArgs: recordIds,
        );

        if (records.isNotEmpty) {
          // Remove is_synced field for cloud upload
          final cloudRecords = records.map((r) {
            final cloudRecord = Map<String, dynamic>.from(r);
            cloudRecord.remove('is_synced');
            return cloudRecord;
          }).toList();

          // Batch upsert to Supabase
          await supabase.from(tableName).upsert(cloudRecords);

          // Mark all as successful
          successfulItems.addAll(items.map((item) => item['id'] as int));
        }
      } catch (e) {
        // If batch fails, mark all as failed
        failedItems
            .addAll(items.map((item) => {...item, 'error': e.toString()}));
      }
    }

    // Update queue items
    await db.transaction((txn) async {
      // Remove successful items
      if (successfulItems.isNotEmpty) {
        await txn.delete(
          'sync_queue',
          where: 'id IN (${successfulItems.map((_) => '?').join(', ')})',
          whereArgs: successfulItems,
        );
      }

      // Update failed items
      for (var failedItem in failedItems) {
        final currentAttempts = (failedItem['failed_attempts'] as int?) ?? 0;
        final newAttempts = currentAttempts + 1;

        if (newAttempts >= MAX_RETRY_ATTEMPTS) {
          // Mark as permanently failed
          await txn.update(
            'sync_queue',
            {
              'failed_attempts': MAX_RETRY_ATTEMPTS,
              'error_message': failedItem['error'],
              'last_retry_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [failedItem['id']],
          );
        } else {
          // Update retry count
          await txn.update(
            'sync_queue',
            {
              'failed_attempts': newAttempts,
              'error_message': failedItem['error'],
              'last_retry_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [failedItem['id']],
          );
        }
      }
    });

    print(
        'Batch processing completed: ${successfulItems.length} successful, ${failedItems.length} failed');
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};

    for (var entry in _queryTimes.entries) {
      final times = entry.value;
      final count = _operationCounts[entry.key] ?? 0;

      if (times.isNotEmpty) {
        final totalMs =
            times.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
        final averageMs = totalMs / times.length;
        final maxMs =
            times.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
        final minMs =
            times.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);

        stats[entry.key] = {
          'count': count,
          'average_ms': averageMs.round(),
          'max_ms': maxMs,
          'min_ms': minMs,
          'total_ms': totalMs,
        };
      }
    }

    return stats;
  }

  /// Clear performance statistics
  void clearPerformanceStats() {
    _queryTimes.clear();
    _operationCounts.clear();
  }

  /// Optimized sync all with enhanced performance
  Future<Map<String, Map<String, int>>> syncAllOptimized() async {
    return await _measureQuery('syncAllOptimized', () async {
      print('Starting optimized sync all operations...');

      // Initialize database optimizations
      await initializeOptimizedDatabase();

      final results = <String, Map<String, int>>{};

      try {
        // Process sync queue first
        await processSyncQueueOptimized();

        // Sync core data with original service (these are typically small datasets)
        await _originalSyncService.syncProfilesToLocalDb();
        await _originalSyncService.syncOutletsToLocalDb();
        await _originalSyncService.syncRepsToLocalDb();
        await _originalSyncService.syncCustomersToLocalDb();

        // Use optimized sync for large datasets
        results['products'] = await syncProductsOptimized();
        results['sales'] = await syncSalesOptimized();

        // Use original service for other data (can be optimized later)
        results['stock_balances'] =
            await _originalSyncService.syncStockBalancesToLocalDb();
        results['stock_intake'] =
            await _originalSyncService.syncStockIntakesToLocalDb();
        results['intake_balances'] =
            await _originalSyncService.syncIntakeBalancesToLocalDb();
        results['expenditures'] =
            await _originalSyncService.syncExpendituresToLocalDb();

        // Final sync queue processing
        await processSyncQueueOptimized();

        print('Optimized sync all completed successfully');

        // Print performance stats
        final perfStats = getPerformanceStats();
        print('Performance Statistics:');
        for (var entry in perfStats.entries) {
          print('  ${entry.key}: ${entry.value}');
        }

        return results;
      } catch (e) {
        print('Optimized sync all failed: $e');
        rethrow;
      }
    });
  }
}
