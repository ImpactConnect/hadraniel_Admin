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

    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
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
        date_added TEXT,
        last_updated TEXT,
        description TEXT,
        outlet_id TEXT NOT NULL,
        created_at TEXT
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Drop the old products table
      await db.execute('DROP TABLE IF EXISTS products');

      // Create the new products table
      await db.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          product_name TEXT NOT NULL,
          quantity REAL NOT NULL,
          unit TEXT NOT NULL,
          cost_per_unit REAL NOT NULL,
          total_cost REAL NOT NULL,
          date_added TEXT,
          last_updated TEXT,
          description TEXT,
          outlet_id TEXT NOT NULL,
          created_at TEXT
        )
      ''');
    }
  }

  Future<void> clearAllTables() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('profiles');
      await txn.delete('outlets');
      await txn.delete('products');
      await txn.delete('reps');
    });
  }
}
