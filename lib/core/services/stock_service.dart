import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/stock_balance_model.dart';
import '../models/product_model.dart';
import '../models/outlet_model.dart';
import 'sync_service.dart';

class StockService {
  final DatabaseHelper _db = DatabaseHelper();
  final SyncService _syncService = SyncService();

  Future<void> createStockBalanceTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_balances (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        given_quantity REAL NOT NULL,
        sold_quantity REAL DEFAULT 0,
        balance_quantity REAL NOT NULL,
        last_updated TEXT,
        created_at TEXT,
        synced INTEGER DEFAULT 1
      )
    ''');
  }

  Future<void> insertStockBalance(StockBalance stockBalance) async {
    final db = await _db.database;
    await db.insert(
      'stock_balances',
      stockBalance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<StockBalance>> getStockBalances({
    DateTime? startDate,
    DateTime? endDate,
    String? outletId,
    String? productId,
  }) async {
    final db = await _db.database;
    final List<String> whereConditions = [];
    final List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereConditions.add('created_at >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereConditions.add('created_at <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    if (outletId != null) {
      whereConditions.add('outlet_id = ?');
      whereArgs.add(outletId);
    }

    if (productId != null) {
      whereConditions.add('product_id = ?');
      whereArgs.add(productId);
    }

    final String whereClause =
        whereConditions.isNotEmpty ? whereConditions.join(' AND ') : '';

    final List<Map<String, dynamic>> maps = await db.query(
      'stock_balances',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
    );

    final stockBalances =
        maps.map((map) => StockBalance.fromJson(map)).toList();

    // Calculate values using product costs
    final products = await _syncService.getAllLocalProducts();
    for (var balance in stockBalances) {
      final product = products.firstWhere(
        (p) => p.id == balance.productId,
        orElse: () => Product(
          id: balance.productId,
          productName: 'Unknown',
          quantity: 0,
          unit: 'N/A',
          costPerUnit: 0,
          totalCost: 0,
          dateAdded: DateTime.now(),
          outletId: '',
          createdAt: DateTime.now(),
          isSynced: false,
        ),
      );
      balance.calculateValues(product.costPerUnit);
    }

    return stockBalances;
  }

  Future<Map<String, num>> getTotalStats() async {
    final stockBalances = await getStockBalances();

    double totalStockValue = 0;
    double totalStockQuantity = 0;
    double totalSoldQuantity = 0;
    double totalBalanceValue = 0;

    for (var balance in stockBalances) {
      totalStockValue += balance.totalGivenValue ?? 0;
      totalStockQuantity += balance.givenQuantity;
      totalSoldQuantity += balance.soldQuantity;
      totalBalanceValue += balance.balanceValue ?? 0;
    }

    return {
      'totalStockValue': totalStockValue,
      'totalStockQuantity': totalStockQuantity,
      'totalSoldQuantity': totalSoldQuantity,
      'totalBalanceValue': totalBalanceValue,
    };
  }
}
