import 'dart:io' show Platform, Directory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
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
    final dbFactory = Platform.isWindows || Platform.isLinux
        ? databaseFactoryFfi
        : databaseFactory;

    // Use user-writable directory instead of default path
    String databasePath;
    if (Platform.isWindows) {
      // Use AppData/Local for Windows to avoid permission issues
      final appDataPath = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          Directory.current.path;
      databasePath = join(appDataPath, 'Hadraniel_Admin');
    } else {
      databasePath = await dbFactory.getDatabasesPath();
    }

    final path = join(databasePath, 'admin_app.db');
    print('Database path: $path'); // Debug log

    // Ensure the database directory exists
    final directory = Directory(databasePath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      print('Created database directory: $databasePath');
    }

    return await dbFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
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

    if (oldVersion < 6) {
      // Add is_synced column to sales and sale_items tables if they don't exist
      try {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN is_synced INTEGER DEFAULT 0
        ''');
      } catch (e) {
        print('Error adding is_synced to sales: $e');
      }

      try {
        await db.execute('''
          ALTER TABLE sale_items ADD COLUMN is_synced INTEGER DEFAULT 0
        ''');
      } catch (e) {
        print('Error adding is_synced to sale_items: $e');
      }
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

    if (oldVersion < 5) {
      // Add product_distributions table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_distributions (
          id TEXT PRIMARY KEY,
          product_name TEXT NOT NULL,
          outlet_id TEXT NOT NULL,
          outlet_name TEXT NOT NULL,
          quantity REAL NOT NULL,
          cost_per_unit REAL NOT NULL,
          total_cost REAL NOT NULL,
          distribution_date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          is_synced INTEGER DEFAULT 0,
          FOREIGN KEY (outlet_id) REFERENCES outlets (id)
        )
      ''');
    }

    if (oldVersion < 7) {
      // Add expenditure tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenditures (
          id TEXT PRIMARY KEY,
          outlet_id TEXT NOT NULL,
          outlet_name TEXT NOT NULL,
          category TEXT NOT NULL,
          description TEXT NOT NULL,
          amount REAL NOT NULL,
          payment_method TEXT DEFAULT 'cash',
          receipt_number TEXT,
          vendor_name TEXT,
          date_incurred TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          is_recurring INTEGER DEFAULT 0,
          recurring_frequency TEXT,
          notes TEXT,
          status TEXT DEFAULT 'pending',
          approved_by TEXT,
          rejected_by TEXT,
          rejection_reason TEXT,
          is_synced INTEGER DEFAULT 0,
          FOREIGN KEY (outlet_id) REFERENCES outlets (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenditure_categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          color TEXT NOT NULL DEFAULT '#2196F3',
          is_active INTEGER DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 8) {
      // Add approval workflow columns to expenditures table if they don't exist
      try {
        await db.execute(
            'ALTER TABLE expenditures ADD COLUMN status TEXT DEFAULT "pending"');
      } catch (e) {
        // Column might already exist, ignore error
      }

      try {
        await db
            .execute('ALTER TABLE expenditures ADD COLUMN approved_by TEXT');
      } catch (e) {
        // Column might already exist, ignore error
      }

      try {
        await db
            .execute('ALTER TABLE expenditures ADD COLUMN rejected_by TEXT');
      } catch (e) {
        // Column might already exist, ignore error
      }

      try {
        await db.execute(
            'ALTER TABLE expenditures ADD COLUMN rejection_reason TEXT');
      } catch (e) {
        // Column might already exist, ignore error
      }
    }

    if (oldVersion < 9) {
      // Add is_synced column to intake_balances table if it doesn't exist
      try {
        await db.execute(
            'ALTER TABLE intake_balances ADD COLUMN is_synced INTEGER DEFAULT 0');
      } catch (e) {
        // Column might already exist, ignore error
        print('Error adding is_synced to intake_balances: $e');
      }
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

    // Stock intake table
    await db.execute('''
      CREATE TABLE stock_intake (
        id TEXT PRIMARY KEY,
        product_name TEXT NOT NULL,
        quantity_received REAL NOT NULL,
        unit TEXT NOT NULL,
        cost_per_unit REAL NOT NULL,
        total_cost REAL NOT NULL,
        description TEXT,
        date_received TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // Intake balances table
    await db.execute('''
      CREATE TABLE intake_balances (
        id TEXT PRIMARY KEY,
        product_name TEXT NOT NULL,
        total_received REAL NOT NULL,
        total_assigned REAL DEFAULT 0,
        balance_quantity REAL NOT NULL,
        last_updated TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // Product distributions table
    await db.execute('''
      CREATE TABLE product_distributions (
        id TEXT PRIMARY KEY,
        product_name TEXT NOT NULL,
        outlet_id TEXT NOT NULL,
        outlet_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        cost_per_unit REAL NOT NULL,
        total_cost REAL NOT NULL,
        distribution_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (outlet_id) REFERENCES outlets (id)
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
        rep_id TEXT,
        vat REAL DEFAULT 0,
        total_amount REAL DEFAULT 0,
        amount_paid REAL DEFAULT 0,
        outstanding_amount REAL DEFAULT 0,
        is_paid INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (outlet_id) REFERENCES outlets (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (rep_id) REFERENCES profiles (id)
      )
    ''');

    // Sale Items table
    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        total REAL NOT NULL,
        created_at TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
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

    // Stock Balances table
    await db.execute('''
      CREATE TABLE stock_balances (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        given_quantity REAL NOT NULL,
        sold_quantity REAL DEFAULT 0,
        balance_quantity REAL NOT NULL,
        last_updated TEXT,
        created_at TEXT,
        synced INTEGER DEFAULT 1,
        FOREIGN KEY (outlet_id) REFERENCES outlets (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Expenditures table
    await db.execute('''
      CREATE TABLE expenditures (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        outlet_name TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        receipt_number TEXT,
        vendor_name TEXT,
        date_incurred TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_recurring INTEGER DEFAULT 0,
        recurring_frequency TEXT,
        next_due_date TEXT,
        status TEXT DEFAULT 'pending',
        approved_by TEXT,
        rejected_by TEXT,
        rejection_reason TEXT,
        notes TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (outlet_id) REFERENCES outlets (id)
      )
    ''');

    // Expenditure Categories table
    await db.execute('''
      CREATE TABLE expenditure_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#2196F3',
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> clearAllTables() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('profiles');
      await txn.delete('outlets');
      await txn.delete('products');
      await txn.delete('reps');
      await txn.delete('sale_items');
      await txn.delete('sales');
      await txn.delete('customers');
      await txn.delete('sync_queue');
      await txn.delete('stock_balances');
      await txn.delete('product_distributions');
      await txn.delete('expenditures');
      await txn.delete('expenditure_categories');
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
