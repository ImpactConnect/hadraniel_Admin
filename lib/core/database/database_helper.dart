import 'dart:io' show Platform, Directory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_migration_v11.dart';
import 'database_migration_v12.dart';
import 'database_migration_v15.dart';

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

  // Expose helpers to safely close and reopen the database when needed (e.g., backups)
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('Database closed and reset to null');
    }
  }

  Future<void> reopenDatabase() async {
    await database; // Triggers lazy reinitialization
    print('Database reopened');
  }

  Future<String> getDatabasePath() async {
    final db = await database;
    return db.path;
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

    final database = await dbFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 18,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      ),
    );

    return database;
  }

  Future<void> _onOpen(Database db) async {
    // Enable WAL mode for better concurrency and crash recovery
    await db.execute('PRAGMA journal_mode=WAL');
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys=ON');
    // Set synchronous mode to NORMAL for better performance with WAL
    await db.execute('PRAGMA synchronous=NORMAL');
    // Set cache size to 10MB for better performance
    await db.execute('PRAGMA cache_size=10000');
    // Set busy timeout to 5 seconds to prevent indefinite locks
    await db.execute('PRAGMA busy_timeout=5000');
    print('Database opened with WAL mode and optimizations enabled');
    
    // Auto-migration: Add missing columns for v18 if they don't exist
    // This ensures seamless migration without user intervention
    await _ensureV18Columns(db);
  }

  /// Ensures v18 columns exist (for automatic migration)
  /// Checks and adds status tracking columns if missing
  Future<void> _ensureV18Columns(Database db) async {
    try {
      // Check if status column exists
      final result = await db.rawQuery("PRAGMA table_info(products)");
      final hasStatus = result.any((col) => col['name'] == 'status');
      
      if (!hasStatus) {
        print('Auto-migration: Adding v18 columns to products table...');
        
        // Add status column
        await db.execute(
          'ALTER TABLE products ADD COLUMN status TEXT DEFAULT "active"'
        );
        
        // Add closed_at column
        await db.execute(
          'ALTER TABLE products ADD COLUMN closed_at TEXT'
        );
        
        // Add closed_reason column
        await db.execute(
          'ALTER TABLE products ADD COLUMN closed_reason TEXT'
        );
        
        // Set all existing products to active
        await db.execute(
          "UPDATE products SET status = 'active' WHERE status IS NULL"
        );
        
        // Update database version
        await db.execute('PRAGMA user_version = 18');
        
        print('✅ Auto-migration completed: v18 columns added');
      }
    } catch (e) {
      print('Auto-migration check: $e (columns may already exist)');
      // Non-fatal - columns might already exist
    }
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

    if (oldVersion < 10) {
      // Enhance sync_queue table with retry capabilities
      try {
        await db.execute(
            'ALTER TABLE sync_queue ADD COLUMN failed_attempts INTEGER DEFAULT 0');
      } catch (e) {
        // Column might already exist, ignore error
        print('Error adding failed_attempts to sync_queue: $e');
      }

      try {
        await db
            .execute('ALTER TABLE sync_queue ADD COLUMN error_message TEXT');
      } catch (e) {
        // Column might already exist, ignore error
        print('Error adding error_message to sync_queue: $e');
      }

      try {
        await db
            .execute('ALTER TABLE sync_queue ADD COLUMN last_retry_at TEXT');
      } catch (e) {
        // Column might already exist, ignore error
        print('Error adding last_retry_at to sync_queue: $e');
      }
    }

    if (oldVersion < 11) {
      // Apply performance indexes and schema fixes
      await DatabaseMigrationV11.applyMigration(db);

      // Verify migration was successful
      final migrationSuccess = await DatabaseMigrationV11.verifyMigration(db);
      if (migrationSuccess) {
        print('Database migration v11 completed successfully');
      } else {
        print('Warning: Database migration v11 may not have completed fully');
      }
    }

    if (oldVersion < 12) {
      // Apply foreign key cascade delete constraints
      await DatabaseMigrationV12.applyMigration(db);

      // Verify migration was successful
      final migrationSuccess = await DatabaseMigrationV12.verifyMigration(db);
      if (migrationSuccess) {
        print('Database migration v12 completed successfully');
      } else {
        print('Warning: Database migration v12 may not have completed fully');
      }
    }

    if (oldVersion < 13) {
      // Add stock count tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_counts (
          id TEXT PRIMARY KEY,
          outlet_id TEXT NOT NULL,
          count_date TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'in_progress',
          created_by TEXT NOT NULL,
          completed_at TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (outlet_id) REFERENCES outlets (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_count_items (
          id TEXT PRIMARY KEY,
          stock_count_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          product_name TEXT NOT NULL,
          theoretical_quantity REAL NOT NULL DEFAULT 0,
          actual_quantity REAL NOT NULL DEFAULT 0,
          variance REAL NOT NULL DEFAULT 0,
          variance_percentage REAL NOT NULL DEFAULT 0,
          cost_per_unit REAL NOT NULL DEFAULT 0,
          value_impact REAL NOT NULL DEFAULT 0,
          adjustment_reason TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (stock_count_id) REFERENCES stock_counts (id),
          FOREIGN KEY (product_id) REFERENCES products (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_adjustments (
          id TEXT PRIMARY KEY,
          product_id TEXT NOT NULL,
          outlet_id TEXT NOT NULL,
          product_name TEXT NOT NULL,
          outlet_name TEXT NOT NULL,
          adjustment_quantity REAL NOT NULL,
          adjustment_type TEXT NOT NULL,
          reason TEXT NOT NULL,
          reason_details TEXT,
          cost_per_unit REAL NOT NULL DEFAULT 0,
          value_impact REAL NOT NULL DEFAULT 0,
          created_by TEXT NOT NULL,
          approved_by TEXT,
          approved_at TEXT,
          status TEXT NOT NULL DEFAULT 'pending',
          stock_count_id TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (product_id) REFERENCES products (id),
          FOREIGN KEY (outlet_id) REFERENCES outlets (id),
          FOREIGN KEY (stock_count_id) REFERENCES stock_counts (id)
        )
      ''');
    }

    if (oldVersion < 14) {
      // Add marketers and marketer_targets tables for upgrades
      await db.execute('''
        CREATE TABLE IF NOT EXISTS marketers (
          id TEXT PRIMARY KEY,
          full_name TEXT NOT NULL,
          email TEXT NOT NULL,
          phone TEXT,
          outlet_id TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'active',
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (outlet_id) REFERENCES outlets (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS marketer_targets (
          id TEXT PRIMARY KEY,
          marketer_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          outlet_id TEXT NOT NULL,
          target_quantity REAL,
          target_revenue REAL,
          target_type TEXT NOT NULL DEFAULT 'quantity',
          start_date TEXT NOT NULL,
          end_date TEXT NOT NULL,
          current_quantity REAL NOT NULL DEFAULT 0,
          current_revenue REAL NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'active',
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (marketer_id) REFERENCES marketers (id),
          FOREIGN KEY (product_id) REFERENCES products (id),
          FOREIGN KEY (outlet_id) REFERENCES outlets (id)
        )
      ''');
    }

    if (oldVersion < 15) {
      // Apply marketer-related performance indexes
      await DatabaseMigrationV15.applyMigration(db);

      // Verify migration was successful
      final migrationSuccess = await DatabaseMigrationV15.verifyMigration(db);
      if (migrationSuccess) {
        print('Database migration v15 completed successfully');
      } else {
        print('Warning: Database migration v15 may not have completed fully');
      }
    }

    if (oldVersion < 16) {
      // Add product_name to sale_items table
      try {
        await db.execute('ALTER TABLE sale_items ADD COLUMN product_name TEXT');
      } catch (e) {
        // Column might already exist, ignore error
        print('Error adding product_name to sale_items: $e');
      }
    }

    if (oldVersion < 17) {
      // Remove foreign key constraint on sale_items
      // 1. Rename existing table
      await db.execute('ALTER TABLE sale_items RENAME TO sale_items_backup');

      // 2. Create new table without FK constraint on product_id
      await db.execute('''
        CREATE TABLE sale_items (
          id TEXT PRIMARY KEY,
          sale_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          product_name TEXT,
          quantity REAL NOT NULL,
          unit_price REAL NOT NULL,
          total_price REAL NOT NULL,
          created_at TEXT,
          is_synced INTEGER DEFAULT 0,
          FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
        )
      ''');

      // 3. Copy data from backup table
      await db.execute('''
        INSERT INTO sale_items (
          id, sale_id, product_id, product_name, quantity, 
          unit_price, total_price, created_at, is_synced
        )
        SELECT 
          id, sale_id, product_id, product_name, quantity, 
          unit_price, total_price, created_at, is_synced
        FROM sale_items_backup
      ''');

      // 4. Drop backup table
      await db.execute('DROP TABLE sale_items_backup');
    }

    if (oldVersion < 18) {
      // Add product status tracking for price change history
      // This allows closing old assignments and creating new ones at different prices
      try {
        await db.execute('ALTER TABLE products ADD COLUMN status TEXT DEFAULT "active"');
        print('Added status column to products table');
      } catch (e) {
        print('Error adding status column (may already exist): $e');
      }

      try {
        await db.execute('ALTER TABLE products ADD COLUMN closed_at TEXT');
        print('Added closed_at column to products table');
      } catch (e) {
        print('Error adding closed_at column (may already exist): $e');
      }

      try {
        await db.execute('ALTER TABLE products ADD COLUMN closed_reason TEXT');
        print('Added closed_reason column to products table');
      } catch (e) {
        print('Error adding closed_reason column (may already exist): $e');
      }

      // Set all existing products to 'active' status
      await db.execute("UPDATE products SET status = 'active' WHERE status IS NULL");
      print('Migration v18: Product status tracking completed');
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
        name TEXT NOT NULL,
        location TEXT NOT NULL,
        created_at TEXT NOT NULL
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
        product_name TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        created_at TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
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

    // Stock Count tables
    await db.execute('''
      CREATE TABLE stock_counts (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        count_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'in_progress',
        created_by TEXT NOT NULL,
        completed_at TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (outlet_id) REFERENCES outlets (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_count_items (
        id TEXT PRIMARY KEY,
        stock_count_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        theoretical_quantity REAL NOT NULL DEFAULT 0,
        actual_quantity REAL NOT NULL DEFAULT 0,
        variance REAL NOT NULL DEFAULT 0,
        variance_percentage REAL NOT NULL DEFAULT 0,
        cost_per_unit REAL NOT NULL DEFAULT 0,
        value_impact REAL NOT NULL DEFAULT 0,
        adjustment_reason TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (stock_count_id) REFERENCES stock_counts (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_adjustments (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        outlet_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        outlet_name TEXT NOT NULL,
        adjustment_quantity REAL NOT NULL,
        adjustment_type TEXT NOT NULL,
        reason TEXT NOT NULL,
        reason_details TEXT,
        cost_per_unit REAL NOT NULL DEFAULT 0,
        value_impact REAL NOT NULL DEFAULT 0,
        created_by TEXT NOT NULL,
        approved_by TEXT,
        approved_at TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        stock_count_id TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (outlet_id) REFERENCES outlets (id),
        FOREIGN KEY (stock_count_id) REFERENCES stock_counts (id)
      )
    ''');
    // Marketers table
    await db.execute('''
      CREATE TABLE marketers (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT,
        outlet_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (outlet_id) REFERENCES outlets (id)
      )
    ''');

    // Marketer Targets table
    await db.execute('''
      CREATE TABLE marketer_targets (
        id TEXT PRIMARY KEY,
        marketer_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        outlet_id TEXT NOT NULL,
        target_quantity REAL,
        target_revenue REAL,
        target_type TEXT NOT NULL DEFAULT 'quantity',
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        current_quantity REAL NOT NULL DEFAULT 0,
        current_revenue REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (marketer_id) REFERENCES marketers (id),
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (outlet_id) REFERENCES outlets (id)
      )
    ''');

    // Performance indexes for fresh installs (v15)
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_marketers_outlet_id ON marketers(outlet_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_marketers_status ON marketers(status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_marketers_created_at ON marketers(created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_marketers_outlet_status ON marketers(outlet_id, status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_marketer_targets_marketer_id ON marketer_targets(marketer_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_marketer_targets_product_id ON marketer_targets(product_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_marketer_targets_outlet_id ON marketer_targets(outlet_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_marketer_targets_status ON marketer_targets(status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_marketer_targets_created_at ON marketer_targets(created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_marketer_targets_period ON marketer_targets(start_date, end_date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_marketer_targets_marketer_product ON marketer_targets(marketer_id, product_id)');
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
      await txn.delete('stock_count_items');
      await txn.delete('stock_adjustments');
      await txn.delete('stock_counts');
    });
  }

  // Check database integrity for corruption detection
  Future<bool> checkDatabaseIntegrity() async {
    try {
      final db = await database;
      final result = await db.rawQuery('PRAGMA integrity_check');
      final isOk = result.first['integrity_check'] == 'ok';
      
      if (!isOk) {
        print('Database integrity check failed: ${result.first}');
      } else {
        print('Database integrity check passed');
      }
      
      return isOk;
    } catch (e) {
      print('Database integrity check error: $e');
      return false;
    }
  }

  // Repair database by closing and reinitializing
  Future<void> repairDatabase() async {
    print('Attempting database repair...');
    try {
      // Close current connection
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      // Reinitialize (will trigger onCreate/onOpen)
      _database = await _initDatabase();
      
      print('Database repaired successfully');
    } catch (e) {
      print('Database repair failed: $e');
      rethrow;
    }
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
