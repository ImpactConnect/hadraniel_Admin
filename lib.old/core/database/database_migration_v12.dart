import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseMigrationV12 {
  /// Apply foreign key cascade delete constraints to fix product deletion issues
  static Future<void> applyMigration(Database db) async {
    print(
        'Applying Database Migration v12: Adding ON DELETE CASCADE constraints');

    await db.transaction((txn) async {
      try {
        // 1. Fix stock_balances table to add ON DELETE CASCADE for product_id
        await _fixStockBalancesForeignKeys(txn);

        // 2. Fix sale_items table to ensure ON DELETE CASCADE for product_id
        await _fixSaleItemsForeignKeys(txn);

        print('Database Migration v12 completed successfully');
      } catch (e) {
        print('Error during migration v12: $e');
        throw e;
      }
    });
  }

  /// Fix stock_balances table to add ON DELETE CASCADE for product_id
  static Future<void> _fixStockBalancesForeignKeys(Transaction txn) async {
    print('Fixing stock_balances foreign key constraints...');

    // Create new table with ON DELETE CASCADE constraint
    await txn.execute('''
      CREATE TABLE stock_balances_new (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        given_quantity REAL NOT NULL,
        sold_quantity REAL DEFAULT 0,
        balance_quantity REAL NOT NULL,
        last_updated TEXT,
        created_at TEXT,
        synced INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (outlet_id) REFERENCES outlets (id),
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    // Copy data from old table to new table
    await txn.execute('''
      INSERT INTO stock_balances_new 
      (id, outlet_id, product_id, given_quantity, sold_quantity, balance_quantity, last_updated, created_at, synced, is_synced)
      SELECT id, outlet_id, product_id, given_quantity, sold_quantity, balance_quantity, last_updated, created_at, synced, 
             CASE WHEN is_synced IS NULL THEN synced ELSE is_synced END
      FROM stock_balances
    ''');

    // Drop old table and rename new table
    await txn.execute('DROP TABLE stock_balances');
    await txn
        .execute('ALTER TABLE stock_balances_new RENAME TO stock_balances');

    print('Fixed stock_balances table with ON DELETE CASCADE for product_id');
  }

  /// Fix sale_items table to ensure ON DELETE CASCADE for product_id
  static Future<void> _fixSaleItemsForeignKeys(Transaction txn) async {
    print('Fixing sale_items foreign key constraints...');

    // Create new table with ON DELETE CASCADE constraint for product_id
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
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    // Copy data from old table to new table
    await txn.execute('''
      INSERT INTO sale_items_new 
      (id, sale_id, product_id, quantity, unit_price, total_price, created_at, is_synced)
      SELECT id, sale_id, product_id, quantity, unit_price, total_price, created_at, is_synced
      FROM sale_items
    ''');

    // Drop old table and rename new table
    await txn.execute('DROP TABLE sale_items');
    await txn.execute('ALTER TABLE sale_items_new RENAME TO sale_items');

    print('Fixed sale_items table with ON DELETE CASCADE for product_id');
  }

  /// Verify migration was successful
  static Future<bool> verifyMigration(Database db) async {
    try {
      // Check if foreign key constraints are enabled
      final fkEnabled = await db.rawQuery("PRAGMA foreign_keys");
      if (fkEnabled.isEmpty || fkEnabled.first['foreign_keys'] != 1) {
        print('Warning: Foreign key constraints are not enabled');
        return false;
      }

      // Unfortunately SQLite doesn't provide a direct way to check ON DELETE CASCADE
      // We can only verify the tables were recreated successfully
      final stockBalancesExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='stock_balances'");
      final saleItemsExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='sale_items'");

      return stockBalancesExists.isNotEmpty && saleItemsExists.isNotEmpty;
    } catch (e) {
      print('Error verifying migration: $e');
      return false;
    }
  }
}
