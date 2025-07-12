import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/stock_intake_model.dart';
import '../models/intake_balance_model.dart';
import '../models/product_model.dart';
import 'sync_service.dart';

class StockIntakeService {
  final DatabaseHelper _db = DatabaseHelper();
  final SyncService _syncService = SyncService();
  final Uuid _uuid = const Uuid();

  // Initialize tables
  Future<void> createStockIntakeTable() async {
    final db = await _db.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_intake (
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
  }

  Future<void> createIntakeBalancesTable() async {
    final db = await _db.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS intake_balances (
        id TEXT PRIMARY KEY,
        product_name TEXT NOT NULL,
        total_received REAL NOT NULL,
        total_assigned REAL DEFAULT 0,
        balance_quantity REAL NOT NULL,
        last_updated TEXT NOT NULL
      )
    ''');
  }

  // Add new stock intake
  Future<StockIntake> addIntake({
    required String productName,
    required double quantityReceived,
    required String unit,
    required double costPerUnit,
    String? description,
  }) async {
    final db = await _db.database;
    final totalCost = quantityReceived * costPerUnit;
    final now = DateTime.now();

    final stockIntake = StockIntake(
      id: _uuid.v4(),
      productName: productName,
      quantityReceived: quantityReceived,
      unit: unit,
      costPerUnit: costPerUnit,
      totalCost: totalCost,
      description: description,
      dateReceived: now,
      createdAt: now,
    );

    await db.insert(
      'stock_intake',
      stockIntake.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update intake balances
    await updateBalanceOnNewIntake(productName, quantityReceived);

    return stockIntake;
  }

  // Add stock intake directly from model
  Future<void> addStockIntake(StockIntake stockIntake) async {
    final db = await _db.database;

    await db.insert(
      'stock_intake',
      stockIntake.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update intake balances
    await updateBalanceOnNewIntake(
      stockIntake.productName,
      stockIntake.quantityReceived,
    );
  }

  // Get all stock intakes with optional filters
  Future<List<StockIntake>> getAllIntakes({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
  }) async {
    final db = await _db.database;
    final List<String> whereConditions = [];
    final List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereConditions.add('date_received >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereConditions.add('date_received <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    if (productName != null) {
      whereConditions.add('product_name = ?');
      whereArgs.add(productName);
    }

    final String whereClause = whereConditions.isNotEmpty
        ? whereConditions.join(' AND ')
        : '';

    final List<Map<String, dynamic>> maps = await db.query(
      'stock_intake',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date_received DESC',
    );

    return maps.map((map) => StockIntake.fromMap(map)).toList();
  }

  // Update intake balance when new stock is received
  Future<void> updateBalanceOnNewIntake(
    String productName,
    double quantity,
  ) async {
    final db = await _db.database;
    final now = DateTime.now();

    // Check if product exists in intake_balances
    final List<Map<String, dynamic>> existingBalances = await db.query(
      'intake_balances',
      where: 'product_name = ?',
      whereArgs: [productName],
    );

    if (existingBalances.isNotEmpty) {
      // Update existing balance
      final existingBalance = IntakeBalance.fromMap(existingBalances.first);
      final updatedTotalReceived = existingBalance.totalReceived + quantity;
      final updatedBalanceQuantity =
          updatedTotalReceived - existingBalance.totalAssigned;

      await db.update(
        'intake_balances',
        {
          'total_received': updatedTotalReceived,
          'balance_quantity': updatedBalanceQuantity,
          'last_updated': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existingBalance.id],
      );
    } else {
      // Create new balance record
      final newBalance = IntakeBalance(
        id: _uuid.v4(),
        productName: productName,
        totalReceived: quantity,
        totalAssigned: 0,
        balanceQuantity: quantity,
        lastUpdated: now,
      );

      await db.insert(
        'intake_balances',
        newBalance.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // Update balance when product is assigned to outlet
  Future<bool> updateBalanceOnProductAssignment(
    String productName,
    double quantity,
  ) async {
    final db = await _db.database;
    final now = DateTime.now();

    // Check if product exists in intake_balances
    final List<Map<String, dynamic>> existingBalances = await db.query(
      'intake_balances',
      where: 'product_name = ?',
      whereArgs: [productName],
    );

    if (existingBalances.isEmpty) {
      return false; // Product not found
    }

    final existingBalance = IntakeBalance.fromMap(existingBalances.first);

    // Check if there's enough balance
    if (existingBalance.balanceQuantity < quantity) {
      return false; // Not enough balance
    }

    final updatedTotalAssigned = existingBalance.totalAssigned + quantity;
    final updatedBalanceQuantity =
        existingBalance.totalReceived - updatedTotalAssigned;

    await db.update(
      'intake_balances',
      {
        'total_assigned': updatedTotalAssigned,
        'balance_quantity': updatedBalanceQuantity,
        'last_updated': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [existingBalance.id],
    );

    return true;
  }

  // Get all intake balances
  Future<List<IntakeBalance>> getAllIntakeBalances() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query('intake_balances');
    return maps.map((map) => IntakeBalance.fromMap(map)).toList();
  }

  // Get available products for assignment (with balance > 0)
  Future<List<String>> getAvailableProductsForAssignment() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'intake_balances',
      where: 'balance_quantity > 0',
    );

    return maps.map((map) => map['product_name'] as String).toList();
  }
  
  // Get available products with their balance quantities
  Future<Map<String, double>> getAvailableProductsWithBalance() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'intake_balances',
      where: 'balance_quantity > 0',
    );

    Map<String, double> productsWithBalance = {};
    for (var map in maps) {
      productsWithBalance[map['product_name'] as String] = map['balance_quantity'] as double;
    }
    
    return productsWithBalance;
  }

  // Sync stock intakes to cloud
  Future<void> syncIntakesToCloud() async {
    final db = await _db.database;

    // Get unsynced stock intakes
    final List<Map<String, dynamic>> unsyncedIntakes = await db.query(
      'stock_intake',
      where: 'is_synced = 0',
    );

    for (final intakeMap in unsyncedIntakes) {
      final intake = StockIntake.fromMap(intakeMap);

      // Sync to Supabase
      final success = await _syncService.syncStockIntakeToSupabase(intake);

      if (success) {
        // Update local record as synced
        await db.update(
          'stock_intake',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [intake.id],
        );
      }
    }
  }

  // Mark a stock intake as synced
  Future<void> markIntakeAsSynced(String id) async {
    final db = await _db.database;
    await db.update(
      'stock_intake',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get total value of all stock intakes
  Future<double> getTotalStockValue() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT SUM(total_cost) as total FROM stock_intake',
    );
    return result.first['total'] == null
        ? 0.0
        : (result.first['total'] as num).toDouble();
  }

  // Get count of unique products in stock intake
  Future<int> getUniqueProductCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(DISTINCT product_name) as count FROM stock_intake',
    );
    return result.first['count'] == null
        ? 0
        : (result.first['count'] as num).toInt();
  }
}
