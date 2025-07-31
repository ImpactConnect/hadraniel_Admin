import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/stock_intake_model.dart';
import '../models/intake_balance_model.dart';
import '../models/product_model.dart';
import '../models/product_distribution_model.dart';
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

    final String whereClause =
        whereConditions.isNotEmpty ? whereConditions.join(' AND ') : '';

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
    String outletId,
    String outletName,
    double costPerUnit,
  ) async {
    final db = await _db.database;
    final now = DateTime.now();

    // Wrap all operations in a single transaction to prevent locking
    return await db.transaction((txn) async {
      // Check if product exists in intake_balances
      final List<Map<String, dynamic>> existingBalances = await txn.query(
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

      await txn.update(
        'intake_balances',
        {
          'total_assigned': updatedTotalAssigned,
          'balance_quantity': updatedBalanceQuantity,
          'last_updated': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existingBalance.id],
      );

      // Record the distribution within the same transaction
      final distribution = ProductDistribution(
        id: _uuid.v4(),
        productName: productName,
        outletId: outletId,
        outletName: outletName,
        quantity: quantity,
        costPerUnit: costPerUnit,
        totalCost: quantity * costPerUnit,
        distributionDate: now,
        createdAt: now,
      );

      await txn.insert(
        'product_distributions',
        distribution.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return true;
    });
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
      productsWithBalance[map['product_name'] as String] =
          map['balance_quantity'] as double;
    }

    return productsWithBalance;
  }

  // Get available products with their balance quantities and units
  Future<Map<String, Map<String, dynamic>>> getAvailableProductsWithBalanceAndUnit() async {
    final db = await _db.database;
    
    // Join intake_balances with stock_intake to get unit information
    // We'll get the most recent unit for each product
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        ib.product_name,
        ib.balance_quantity,
        si.unit
      FROM intake_balances ib
      INNER JOIN (
        SELECT 
          product_name,
          unit,
          ROW_NUMBER() OVER (PARTITION BY product_name ORDER BY date_received DESC) as rn
        FROM stock_intake
      ) si ON ib.product_name = si.product_name AND si.rn = 1
      WHERE ib.balance_quantity > 0
    ''');

    Map<String, Map<String, dynamic>> productsWithBalanceAndUnit = {};
    for (var map in maps) {
      final productName = map['product_name'] as String;
      productsWithBalanceAndUnit[productName] = {
        'balance': map['balance_quantity'] as double,
        'unit': map['unit'] as String,
      };
    }

    return productsWithBalanceAndUnit;
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

  // Add a product distribution record
  Future<ProductDistribution> addProductDistribution({
    required String productName,
    required String outletId,
    required String outletName,
    required double quantity,
    required double costPerUnit,
    required DateTime distributionDate,
    Transaction? txn,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final totalCost = quantity * costPerUnit;

    final distribution = ProductDistribution(
      id: _uuid.v4(),
      productName: productName,
      outletId: outletId,
      outletName: outletName,
      quantity: quantity,
      costPerUnit: costPerUnit,
      totalCost: totalCost,
      distributionDate: distributionDate,
      createdAt: now,
    );

    if (txn != null) {
      await txn.insert(
        'product_distributions',
        distribution.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      // Wrap in a transaction if one wasn't provided
      await db.transaction((txn) async {
        await txn.insert(
          'product_distributions',
          distribution.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
    }

    return distribution;
  }

  // Get product distributions by product name
  Future<List<ProductDistribution>> getProductDistributions(
    String productName,
  ) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'product_distributions',
      where: 'product_name = ?',
      whereArgs: [productName],
      orderBy: 'distribution_date DESC',
    );

    return maps.map((map) => ProductDistribution.fromMap(map)).toList();
  }

  // Get all product distributions
  Future<List<ProductDistribution>> getAllProductDistributions() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'product_distributions',
      orderBy: 'distribution_date DESC',
    );

    return maps.map((map) => ProductDistribution.fromMap(map)).toList();
  }

  // Update stock intake
  Future<void> updateStockIntake(StockIntake stockIntake) async {
    final db = await _db.database;
    
    // Get the original stock intake to calculate balance changes
    final List<Map<String, dynamic>> originalMaps = await db.query(
      'stock_intake',
      where: 'id = ?',
      whereArgs: [stockIntake.id],
    );
    
    if (originalMaps.isNotEmpty) {
      final originalIntake = StockIntake.fromMap(originalMaps.first);
      
      // Update the stock intake record
      await db.update(
        'stock_intake',
        stockIntake.toMap(),
        where: 'id = ?',
        whereArgs: [stockIntake.id],
      );
      
      // Update intake balances if quantity or product changed
      if (originalIntake.productName != stockIntake.productName ||
          originalIntake.quantityReceived != stockIntake.quantityReceived) {
        
        // Subtract the original quantity from the original product
        await _updateBalanceOnIntakeChange(
          originalIntake.productName,
          -originalIntake.quantityReceived,
        );
        
        // Add the new quantity to the new product
        await _updateBalanceOnIntakeChange(
          stockIntake.productName,
          stockIntake.quantityReceived,
        );
      }
    }
  }

  // Delete stock intake
  Future<void> deleteStockIntake(String id) async {
    final db = await _db.database;
    
    // Get the stock intake to update balances
    final List<Map<String, dynamic>> maps = await db.query(
      'stock_intake',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      final stockIntake = StockIntake.fromMap(maps.first);
      
      // Delete the stock intake record
      await db.delete(
        'stock_intake',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      // Update intake balances by subtracting the deleted quantity
      await _updateBalanceOnIntakeChange(
        stockIntake.productName,
        -stockIntake.quantityReceived,
      );
    }
  }

  // Helper method to update balance when intake changes
  Future<void> _updateBalanceOnIntakeChange(
    String productName,
    double quantityChange,
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
      final updatedTotalReceived = existingBalance.totalReceived + quantityChange;
      final updatedBalanceQuantity =
          updatedTotalReceived - existingBalance.totalAssigned;

      if (updatedTotalReceived <= 0) {
        // Delete the balance record if total received becomes 0 or negative
        await db.delete(
          'intake_balances',
          where: 'id = ?',
          whereArgs: [existingBalance.id],
        );
      } else {
        // Update the balance record
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
      }
    } else if (quantityChange > 0) {
      // Create new balance record only if adding quantity
      final newBalance = IntakeBalance(
        id: _uuid.v4(),
        productName: productName,
        totalReceived: quantityChange,
        totalAssigned: 0,
        balanceQuantity: quantityChange,
        lastUpdated: now,
      );

      await db.insert(
        'intake_balances',
        newBalance.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
