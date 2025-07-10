import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await databaseFactoryFfi.getDatabasesPath();
    final path = join(databasePath, 'admin_app.db');
    print('Database path: $path'); // Debug log

    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add is_synced column to products table if it doesn't exist
      await db.execute('''
        ALTER TABLE products ADD COLUMN is_synced INTEGER DEFAULT 0
      ''');
    }

    if (oldVersion < 3) {
      // Add sync_queue and customers tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          record_id TEXT NOT NULL,
          is_delete INTEGER DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id TEXT PRIMARY KEY,
          full_name TEXT NOT NULL,
          phone TEXT,
          outlet_id TEXT NOT NULL,
          total_outstanding REAL DEFAULT 0,
          created_at TEXT NOT NULL,
          is_synced INTEGER DEFAULT 0,
          FOREIGN KEY (outlet_id) REFERENCES outlets (id)
        )
      ''');
    }

    if (oldVersion < 4) {
      // Drop and recreate customers table with correct schema
      await db.execute('DROP TABLE IF EXISTS customers');
      await db.execute(
        '''        CREATE TABLE customers (          id TEXT PRIMARY KEY,          full_name TEXT NOT NULL,          phone TEXT,          outlet_id TEXT,          total_outstanding REAL DEFAULT 0,          created_at TEXT NOT NULL,          is_synced INTEGER DEFAULT 0,          FOREIGN KEY (outlet_id) REFERENCES outlets (id)        )      ''',
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Profiles table
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        outlet_id TEXT,
        full_name TEXT,
        role TEXT,
        created_at TEXT
      )
    ''');

    // Outlets table
    await db.execute('''
      CREATE TABLE outlets (
        id TEXT PRIMARY KEY,
        name TEXT,
        location TEXT,
        created_at TEXT
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        cost_per_unit REAL NOT NULL,
        total_cost REAL NOT NULL,
        date_added TEXT NOT NULL,
        last_updated TEXT,
        description TEXT,
        outlet_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (outlet_id) REFERENCES outlets (id)
      )
    ''');

    // Reps table
    await db.execute('''
      CREATE TABLE reps (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL,
        outlet_id TEXT,
        role TEXT DEFAULT 'rep',
        created_at TEXT
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        customer_id TEXT,
        total_amount REAL,
        is_paid INTEGER DEFAULT 0,
        created_at TEXT,
        FOREIGN KEY (outlet_id) REFERENCES outlets (id)
      )
    ''');

    // Sync Queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        is_delete INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Customers table
    await db.execute(
      '''      CREATE TABLE customers (        id TEXT PRIMARY KEY,        full_name TEXT NOT NULL,        phone TEXT,        outlet_id TEXT,        total_outstanding REAL DEFAULT 0,        created_at TEXT NOT NULL,        is_synced INTEGER DEFAULT 0,        FOREIGN KEY (outlet_id) REFERENCES outlets (id)      )    ''',
    );
  }

  Future<void> clearAllTables() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('profiles');
      await txn.delete('outlets');
      await txn.delete('products');
      await txn.delete('reps');
      await txn.delete('sales');
      await txn.delete('customers');
      await txn.delete('sync_queue');
    });
  }

  Future<void> deleteDatabase() async {
    // Close the database
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    // Get the database path and delete the file
    final databasePath = await databaseFactoryFfi.getDatabasesPath();
    final path = join(databasePath, 'admin_app.db');
    print('Deleting database at: $path');
    await databaseFactoryFfi.deleteDatabase(path);
  }
}
