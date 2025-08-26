import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseMigrationV11 {
  /// Apply critical performance indexes and fix schema inconsistencies
  static Future<void> applyMigration(Database db) async {
    print(
        'Applying Database Migration v11: Performance indexes and schema fixes');

    await db.transaction((txn) async {
      try {
        // 1. Fix schema inconsistency: Rename 'total' to 'total_price' in sale_items
        await _fixSaleItemsColumnNaming(txn);

        // 2. Add critical performance indexes
        await _addPerformanceIndexes(txn);

        // 3. Add missing NOT NULL constraints
        await _addMissingConstraints(txn);

        // 4. Standardize sync column naming
        await _standardizeSyncColumns(txn);

        print('Database Migration v11 completed successfully');
      } catch (e) {
        print('Error during migration v11: $e');
        throw e;
      }
    });
  }

  /// Fix sale_items table column naming inconsistency
  static Future<void> _fixSaleItemsColumnNaming(Transaction txn) async {
    print('Fixing sale_items column naming...');

    // Check if the column needs to be renamed
    final tableInfo = await txn.rawQuery("PRAGMA table_info(sale_items)");
    final hasTotal = tableInfo.any((col) => col['name'] == 'total');
    final hasTotalPrice = tableInfo.any((col) => col['name'] == 'total_price');

    if (hasTotal && !hasTotalPrice) {
      // Create new table with correct column name
      await txn.execute('''
        CREATE TABLE sale_items_new (
          id TEXT PRIMARY KEY,
          sale_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          quantity REAL NOT NULL,
          unit_price REAL NOT NULL,
          total_price REAL NOT NULL,
          created_at TEXT,
          is_synced INTEGER DEFAULT 0,
          FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products (id)
        )
      ''');

      // Copy data from old table to new table
      await txn.execute('''
        INSERT INTO sale_items_new 
        (id, sale_id, product_id, quantity, unit_price, total_price, created_at, is_synced)
        SELECT id, sale_id, product_id, quantity, unit_price, total, created_at, is_synced
        FROM sale_items
      ''');

      // Drop old table and rename new table
      await txn.execute('DROP TABLE sale_items');
      await txn.execute('ALTER TABLE sale_items_new RENAME TO sale_items');

      print('Fixed sale_items column: total -> total_price');
    }
  }

  /// Add critical performance indexes
  static Future<void> _addPerformanceIndexes(Transaction txn) async {
    print('Adding performance indexes...');

    final indexes = [
      // Sales table indexes for common queries
      'CREATE INDEX IF NOT EXISTS idx_sales_outlet_id ON sales(outlet_id)',
      'CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_sales_rep_id ON sales(rep_id)',
      'CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON sales(customer_id)',
      'CREATE INDEX IF NOT EXISTS idx_sales_is_synced ON sales(is_synced)',
      'CREATE INDEX IF NOT EXISTS idx_sales_outlet_date ON sales(outlet_id, created_at)',

      // Sale items indexes for joins and aggregations
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id)',
      'CREATE INDEX IF NOT EXISTS idx_sale_items_product_id ON sale_items(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_sale_items_is_synced ON sale_items(is_synced)',

      // Products table indexes
      'CREATE INDEX IF NOT EXISTS idx_products_outlet_id ON products(outlet_id)',
      'CREATE INDEX IF NOT EXISTS idx_products_name ON products(product_name)',
      'CREATE INDEX IF NOT EXISTS idx_products_is_synced ON products(is_synced)',
      'CREATE INDEX IF NOT EXISTS idx_products_outlet_name ON products(outlet_id, product_name)',

      // Customers table indexes
      'CREATE INDEX IF NOT EXISTS idx_customers_outlet_id ON customers(outlet_id)',
      'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)',
      'CREATE INDEX IF NOT EXISTS idx_customers_is_synced ON customers(is_synced)',

      // Outlets table indexes
      'CREATE INDEX IF NOT EXISTS idx_outlets_name ON outlets(name)',
      'CREATE INDEX IF NOT EXISTS idx_outlets_location ON outlets(location)',

      // Sync queue indexes for performance
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_table_name ON sync_queue(table_name)',
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_created_at ON sync_queue(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_failed_attempts ON sync_queue(failed_attempts)',
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_table_record ON sync_queue(table_name, record_id)',

      // Stock balances indexes
      'CREATE INDEX IF NOT EXISTS idx_stock_balances_outlet_id ON stock_balances(outlet_id)',
      'CREATE INDEX IF NOT EXISTS idx_stock_balances_product_id ON stock_balances(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_stock_balances_outlet_product ON stock_balances(outlet_id, product_id)',

      // Product distributions indexes
      'CREATE INDEX IF NOT EXISTS idx_product_distributions_outlet_id ON product_distributions(outlet_id)',
      'CREATE INDEX IF NOT EXISTS idx_product_distributions_date ON product_distributions(distribution_date)',
      'CREATE INDEX IF NOT EXISTS idx_product_distributions_is_synced ON product_distributions(is_synced)',

      // Expenditures indexes
      'CREATE INDEX IF NOT EXISTS idx_expenditures_outlet_id ON expenditures(outlet_id)',
      'CREATE INDEX IF NOT EXISTS idx_expenditures_category ON expenditures(category)',
      'CREATE INDEX IF NOT EXISTS idx_expenditures_date ON expenditures(date_incurred)',
      'CREATE INDEX IF NOT EXISTS idx_expenditures_is_synced ON expenditures(is_synced)',

      // Intake balances indexes
      'CREATE INDEX IF NOT EXISTS idx_intake_balances_product_name ON intake_balances(product_name)',
      'CREATE INDEX IF NOT EXISTS idx_intake_balances_last_updated ON intake_balances(last_updated)',
      'CREATE INDEX IF NOT EXISTS idx_intake_balances_is_synced ON intake_balances(is_synced)',

      // Stock intake indexes
      'CREATE INDEX IF NOT EXISTS idx_stock_intake_product_name ON stock_intake(product_name)',
      'CREATE INDEX IF NOT EXISTS idx_stock_intake_date ON stock_intake(date_received)',
      'CREATE INDEX IF NOT EXISTS idx_stock_intake_is_synced ON stock_intake(is_synced)',
    ];

    for (final indexSql in indexes) {
      try {
        await txn.execute(indexSql);
      } catch (e) {
        print('Warning: Could not create index: $e');
        // Continue with other indexes even if one fails
      }
    }

    print('Added ${indexes.length} performance indexes');
  }

  /// Add missing NOT NULL constraints where appropriate
  static Future<void> _addMissingConstraints(Transaction txn) async {
    print('Adding missing constraints...');

    try {
      // Check if outlets table needs constraint updates
      final outletsInfo = await txn.rawQuery("PRAGMA table_info(outlets)");
      final nameColumn = outletsInfo.firstWhere((col) => col['name'] == 'name',
          orElse: () => {});

      if (nameColumn.isNotEmpty && nameColumn['notnull'] == 0) {
        // Outlets table needs constraint updates - recreate with proper constraints
        await _recreateOutletsTableWithConstraints(txn);
      }
    } catch (e) {
      print('Warning: Could not update constraints: $e');
    }
  }

  /// Recreate outlets table with proper NOT NULL constraints
  static Future<void> _recreateOutletsTableWithConstraints(
      Transaction txn) async {
    // Create new outlets table with proper constraints
    await txn.execute('''
      CREATE TABLE outlets_new (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        location TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Copy data, setting defaults for NULL values
    await txn.execute('''
      INSERT INTO outlets_new (id, name, location, created_at)
      SELECT 
        id, 
        COALESCE(name, 'Unknown Outlet') as name,
        COALESCE(location, 'Unknown Location') as location,
        COALESCE(created_at, datetime('now')) as created_at
      FROM outlets
    ''');

    // Drop old table and rename new table
    await txn.execute('DROP TABLE outlets');
    await txn.execute('ALTER TABLE outlets_new RENAME TO outlets');

    print('Updated outlets table with NOT NULL constraints');
  }

  /// Standardize sync column naming across all tables
  static Future<void> _standardizeSyncColumns(Transaction txn) async {
    print('Standardizing sync column naming...');

    try {
      // Check stock_balances table for 'synced' column
      final stockBalancesInfo =
          await txn.rawQuery("PRAGMA table_info(stock_balances)");
      final hasSynced = stockBalancesInfo.any((col) => col['name'] == 'synced');
      final hasIsSynced =
          stockBalancesInfo.any((col) => col['name'] == 'is_synced');

      if (hasSynced && !hasIsSynced) {
        // Add is_synced column and copy data from synced column
        await txn.execute(
            'ALTER TABLE stock_balances ADD COLUMN is_synced INTEGER DEFAULT 0');
        await txn.execute('UPDATE stock_balances SET is_synced = synced');

        // Note: We keep the old 'synced' column for backward compatibility
        print('Added is_synced column to stock_balances table');
      }
    } catch (e) {
      print('Warning: Could not standardize sync columns: $e');
    }
  }

  /// Verify migration was successful
  static Future<bool> verifyMigration(Database db) async {
    try {
      // Check if sale_items has total_price column
      final saleItemsInfo = await db.rawQuery("PRAGMA table_info(sale_items)");
      final hasTotalPrice =
          saleItemsInfo.any((col) => col['name'] == 'total_price');

      // Check if critical indexes exist
      final indexes = await db.rawQuery("PRAGMA index_list(sales)");
      final hasOutletIndex =
          indexes.any((idx) => idx['name'].toString().contains('outlet'));

      return hasTotalPrice && hasOutletIndex;
    } catch (e) {
      print('Error verifying migration: $e');
      return false;
    }
  }
}
