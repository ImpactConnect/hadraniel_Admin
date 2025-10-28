import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';

/// Optimized database helper with enhanced performance configurations
class OptimizedDatabaseHelper {
  static final OptimizedDatabaseHelper _instance =
      OptimizedDatabaseHelper._internal();
  factory OptimizedDatabaseHelper() => _instance;
  OptimizedDatabaseHelper._internal();

  static Database? _database;
  static const String _databaseName = 'hadraniel_optimized.db';
  static const int _databaseVersion = 12;

  // Prepared statements cache
  static final Map<String, String> _preparedStatements = {};

  // Connection pool simulation (SQLite doesn't have true pooling)
  static final List<Database> _connectionPool = [];
  static const int _maxConnections = 5;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize database with comprehensive optimizations
  Future<Database> _initDatabase() async {
    try {
      // Initialize FFI for desktop platforms
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      // Get database path
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);

      // Ensure directory exists
      await Directory(dirname(path)).create(recursive: true);

      print('Opening optimized database at: $path');

      // Open database with optimizations
      final database = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
        onConfigure: _onConfigure,
      );

      // Apply additional optimizations
      await _applyAdvancedOptimizations(database);

      // Initialize prepared statements
      await _initializePreparedStatements(database);

      print('Optimized database initialized successfully');
      return database;
    } catch (e) {
      print('Error initializing optimized database: $e');
      rethrow;
    }
  }

  /// Configure database before opening
  Future<void> _onConfigure(Database db) async {
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');

    // Set busy timeout to 30 seconds
    await db.execute('PRAGMA busy_timeout = 30000');

    // Enable recursive triggers
    await db.execute('PRAGMA recursive_triggers = ON');
  }

  /// Apply comprehensive database optimizations
  Future<void> _onOpen(Database db) async {
    print('Applying database optimizations...');

    try {
      // Journal mode optimizations
      await db.execute('PRAGMA journal_mode = WAL');
      await db.execute('PRAGMA wal_autocheckpoint = 1000');

      // Synchronization optimizations
      await db.execute('PRAGMA synchronous = NORMAL');

      // Memory and cache optimizations
      await db.execute('PRAGMA cache_size = 20000'); // 20MB cache
      await db.execute('PRAGMA temp_store = MEMORY');
      await db
          .execute('PRAGMA mmap_size = 536870912'); // 512MB memory-mapped I/O

      // Query optimization
      await db.execute('PRAGMA optimize');
      await db.execute('PRAGMA analysis_limit = 1000');

      // Locking mode optimization
      await db.execute('PRAGMA locking_mode = NORMAL');

      // Page size optimization (must be set before any tables are created)
      // This is typically done during database creation

      print('Basic optimizations applied successfully');
    } catch (e) {
      print('Warning: Some basic optimizations failed: $e');
    }
  }

  /// Apply advanced performance optimizations
  Future<void> _applyAdvancedOptimizations(Database db) async {
    try {
      // Vacuum database to optimize storage
      await db.execute('VACUUM');

      // Analyze all tables for query optimization
      await db.execute('ANALYZE');

      // Create performance monitoring table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS performance_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operation TEXT NOT NULL,
          duration_ms INTEGER NOT NULL,
          timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
          details TEXT
        )
      ''');

      // Create index on performance log
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_performance_log_operation_timestamp 
        ON performance_log(operation, timestamp)
      ''');

      print('Advanced optimizations applied successfully');
    } catch (e) {
      print('Warning: Some advanced optimizations failed: $e');
    }
  }

  /// Initialize prepared statements for common queries
  Future<void> _initializePreparedStatements(Database db) async {
    _preparedStatements.clear();

    // Common SELECT statements
    _preparedStatements['select_product_by_id'] = '''
      SELECT id, name, price, stock_quantity, is_synced 
      FROM products WHERE id = ?
    ''';

    _preparedStatements['select_unsynced_products'] = '''
      SELECT * FROM products WHERE is_synced = 0 LIMIT ?
    ''';

    _preparedStatements['select_sales_by_date_range'] = '''
      SELECT * FROM sales 
      WHERE created_at BETWEEN ? AND ? 
      ORDER BY created_at DESC LIMIT ?
    ''';

    _preparedStatements['select_sale_items_by_sale_id'] = '''
      SELECT si.*, p.name as product_name, p.price as unit_price
      FROM sale_items si
      JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?
    ''';

    // Common UPDATE statements
    _preparedStatements['update_product_sync_status'] = '''
      UPDATE products SET is_synced = ? WHERE id = ?
    ''';

    _preparedStatements['update_sale_sync_status'] = '''
      UPDATE sales SET is_synced = ? WHERE id = ?
    ''';

    _preparedStatements['update_stock_quantity'] = '''
      UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?
    ''';

    // Common INSERT statements
    _preparedStatements['insert_sync_queue'] = '''
      INSERT INTO sync_queue (table_name, record_id, operation, is_delete, created_at)
      VALUES (?, ?, ?, ?, ?)
    ''';

    _preparedStatements['insert_performance_log'] = '''
      INSERT INTO performance_log (operation, duration_ms, details)
      VALUES (?, ?, ?)
    ''';

    // Common DELETE statements
    _preparedStatements['delete_synced_queue_items'] = '''
      DELETE FROM sync_queue WHERE id IN (
        SELECT id FROM sync_queue WHERE table_name = ? AND is_delete = 0 LIMIT ?
      )
    ''';

    print(
        'Prepared statements initialized: ${_preparedStatements.length} statements');
  }

  /// Get a prepared statement by name
  String? getPreparedStatement(String name) {
    return _preparedStatements[name];
  }

  /// Execute a prepared statement with performance logging
  Future<List<Map<String, dynamic>>> queryPrepared(
    String statementName,
    List<dynamic> arguments, {
    bool logPerformance = true,
  }) async {
    final statement = _preparedStatements[statementName];
    if (statement == null) {
      throw ArgumentError('Prepared statement not found: $statementName');
    }

    final stopwatch = Stopwatch()..start();

    try {
      final db = await database;
      final result = await db.rawQuery(statement, arguments);

      stopwatch.stop();

      if (logPerformance) {
        await _logPerformance(statementName, stopwatch.elapsedMilliseconds, {
          'type': 'query',
          'rows': result.length,
          'args': arguments.length,
        });
      }

      return result;
    } catch (e) {
      stopwatch.stop();
      print('Error executing prepared statement $statementName: $e');
      rethrow;
    }
  }

  /// Execute a prepared update/insert/delete with performance logging
  Future<int> executePrepared(
    String statementName,
    List<dynamic> arguments, {
    bool logPerformance = true,
  }) async {
    final statement = _preparedStatements[statementName];
    if (statement == null) {
      throw ArgumentError('Prepared statement not found: $statementName');
    }

    final stopwatch = Stopwatch()..start();

    try {
      final db = await database;
      final result = await db.rawUpdate(statement, arguments);

      stopwatch.stop();

      if (logPerformance) {
        await _logPerformance(statementName, stopwatch.elapsedMilliseconds, {
          'type': 'execute',
          'affected_rows': result,
          'args': arguments.length,
        });
      }

      return result;
    } catch (e) {
      stopwatch.stop();
      print('Error executing prepared statement $statementName: $e');
      rethrow;
    }
  }

  /// Batch execute prepared statements
  Future<List<int>> batchExecutePrepared(
    String statementName,
    List<List<dynamic>> argumentsList, {
    bool logPerformance = true,
  }) async {
    final statement = _preparedStatements[statementName];
    if (statement == null) {
      throw ArgumentError('Prepared statement not found: $statementName');
    }

    final stopwatch = Stopwatch()..start();

    try {
      final db = await database;
      final batch = db.batch();

      for (var arguments in argumentsList) {
        batch.rawUpdate(statement, arguments);
      }

      final results = await batch.commit();
      stopwatch.stop();

      if (logPerformance) {
        await _logPerformance(
            '${statementName}_batch', stopwatch.elapsedMilliseconds, {
          'type': 'batch_execute',
          'batch_size': argumentsList.length,
          'total_affected_rows':
              results.fold<int>(0, (sum, result) => sum + (result as int)),
        });
      }

      return results.cast<int>();
    } catch (e) {
      stopwatch.stop();
      print('Error executing batch prepared statement $statementName: $e');
      rethrow;
    }
  }

  /// Log performance metrics
  Future<void> _logPerformance(
      String operation, int durationMs, Map<String, dynamic> details) async {
    try {
      // Only log slow operations to avoid overhead
      if (durationMs > 100) {
        final db = await database;
        await db.insert('performance_log', {
          'operation': operation,
          'duration_ms': durationMs,
          'details': details.toString(),
        });

        print('SLOW OPERATION: $operation took ${durationMs}ms - $details');
      }
    } catch (e) {
      // Don't let performance logging break the main operation
      print('Warning: Performance logging failed: $e');
    }
  }

  /// Get performance statistics
  Future<Map<String, dynamic>> getPerformanceStats() async {
    try {
      final db = await database;

      // Get operation statistics
      final stats = await db.rawQuery('''
        SELECT 
          operation,
          COUNT(*) as count,
          AVG(duration_ms) as avg_duration,
          MIN(duration_ms) as min_duration,
          MAX(duration_ms) as max_duration,
          SUM(duration_ms) as total_duration
        FROM performance_log 
        WHERE timestamp > datetime('now', '-1 day')
        GROUP BY operation
        ORDER BY avg_duration DESC
      ''');

      // Get overall statistics
      final overall = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_operations,
          AVG(duration_ms) as overall_avg,
          SUM(duration_ms) as total_time
        FROM performance_log 
        WHERE timestamp > datetime('now', '-1 day')
      ''');

      return {
        'operations': stats,
        'overall': overall.isNotEmpty ? overall.first : {},
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error getting performance stats: $e');
      return {'error': e.toString()};
    }
  }

  /// Clean old performance logs
  Future<void> cleanPerformanceLogs({int daysToKeep = 7}) async {
    try {
      final db = await database;
      final deleted = await db.delete(
        'performance_log',
        where: 'timestamp < datetime(\'now\', \'-$daysToKeep days\')',
      );
      print('Cleaned $deleted old performance log entries');
    } catch (e) {
      print('Error cleaning performance logs: $e');
    }
  }

  /// Optimize database (run periodically)
  Future<void> optimizeDatabase() async {
    final stopwatch = Stopwatch()..start();

    try {
      final db = await database;

      print('Starting database optimization...');

      // Update table statistics
      await db.execute('ANALYZE');

      // Optimize query planner
      await db.execute('PRAGMA optimize');

      // Clean up WAL file if it's getting large
      final walInfo = await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      print('WAL checkpoint result: $walInfo');

      // Clean old performance logs
      await cleanPerformanceLogs();

      stopwatch.stop();
      print(
          'Database optimization completed in ${stopwatch.elapsedMilliseconds}ms');

      await _logPerformance(
          'database_optimization', stopwatch.elapsedMilliseconds, {
        'type': 'maintenance',
      });
    } catch (e) {
      stopwatch.stop();
      print('Database optimization failed: $e');
    }
  }

  /// Get database size information
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      final db = await database;

      // Get page count and page size
      final pageCount = await db.rawQuery('PRAGMA page_count');
      final pageSize = await db.rawQuery('PRAGMA page_size');
      final walSize = await db.rawQuery('PRAGMA wal_checkpoint');

      // Get table sizes
      final tables = await db.rawQuery('''
        SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'
      ''');

      final tableSizes = <String, int>{};
      for (var table in tables) {
        final tableName = table['name'] as String;
        final count =
            await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
        tableSizes[tableName] = count.first['count'] as int;
      }

      final totalPages =
          pageCount.isNotEmpty ? pageCount.first['page_count'] as int : 0;
      final pageSizeBytes =
          pageSize.isNotEmpty ? pageSize.first['page_size'] as int : 0;
      final totalSizeBytes = totalPages * pageSizeBytes;

      return {
        'total_size_bytes': totalSizeBytes,
        'total_size_mb': (totalSizeBytes / (1024 * 1024)).toStringAsFixed(2),
        'page_count': totalPages,
        'page_size_bytes': pageSizeBytes,
        'table_row_counts': tableSizes,
        'wal_info': walSize,
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error getting database info: $e');
      return {'error': e.toString()};
    }
  }

  /// Create database tables (called during database creation)
  Future<void> _onCreate(Database db, int version) async {
    print('Creating optimized database tables...');

    // Set optimal page size before creating tables
    await db.execute('PRAGMA page_size = 4096');

    // Create all tables with optimized schemas
    await _createOptimizedTables(db);

    // Create performance indexes
    await _createPerformanceIndexes(db);

    print('Optimized database tables created successfully');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');

    // Add upgrade logic here as needed
    if (oldVersion < 12) {
      // Add performance monitoring table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS performance_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operation TEXT NOT NULL,
          duration_ms INTEGER NOT NULL,
          timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
          details TEXT
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_performance_log_operation_timestamp 
        ON performance_log(operation, timestamp)
      ''');
    }
  }

  /// Create optimized table schemas
  Future<void> _createOptimizedTables(Database db) async {
    // This would include all your existing table creation logic
    // but with optimized column types, constraints, and indexes

    // Example optimized products table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL DEFAULT 0,
        stock_quantity INTEGER NOT NULL DEFAULT 0,
        category_id TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Add other table creation statements here...
  }

  /// Create performance-optimized indexes
  Future<void> _createPerformanceIndexes(Database db) async {
    // Products indexes
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_is_synced ON products(is_synced)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_updated_at ON products(updated_at)');

    // Add other index creation statements here...

    print('Performance indexes created successfully');
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('Optimized database connection closed');
    }
  }

  /// Reset database (for testing/development)
  Future<void> resetDatabase() async {
    try {
      await close();

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);

      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        print('Database file deleted');
      }

      // Clear prepared statements
      _preparedStatements.clear();

      print('Database reset completed');
    } catch (e) {
      print('Error resetting database: $e');
      rethrow;
    }
  }
}
