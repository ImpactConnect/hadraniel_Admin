import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/stock_count_model.dart';
import '../models/stock_count_item_model.dart';
import '../models/stock_adjustment_model.dart';
import '../models/product_model.dart';
import '../models/outlet_model.dart';
import '../models/stock_balance_model.dart';

class StockCountService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  // Note: Tables are now created automatically by DatabaseHelper
  // No need for manual table initialization

  // Create a new stock count session
  Future<StockCount> createStockCount({
    required String outletId,
    required String createdBy,
    DateTime? countDate,
    String? notes,
  }) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();

    final stockCount = StockCount(
      id: _uuid.v4(),
      outletId: outletId,
      countDate: countDate ?? now,
      status: 'in_progress',
      createdBy: createdBy,
      notes: notes,
      createdAt: now,
    );

    await db.insert('stock_counts', stockCount.toMap());
    return stockCount;
  }

  // Get theoretical quantities for products in an outlet
  Future<Map<String, double>> getTheoreticalQuantities(String outletId) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT 
        p.id as product_id,
        p.product_name,
        COALESCE(sb.balance_quantity, 0) as theoretical_quantity
      FROM products p
      LEFT JOIN stock_balances sb ON p.id = sb.product_id AND sb.outlet_id = ?
      WHERE p.outlet_id = ? OR sb.outlet_id = ?
      GROUP BY p.id, p.product_name
    ''', [outletId, outletId, outletId]);

    Map<String, double> quantities = {};
    for (var row in result) {
      quantities[row['product_id'] as String] =
          (row['theoretical_quantity'] as num).toDouble();
    }

    return quantities;
  }

  // Get actual stocked-in quantities (given quantities) for products in an outlet
  Future<Map<String, double>> getStockedInQuantities(String outletId) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT 
        p.id as product_id,
        p.product_name,
        COALESCE(sb.given_quantity, 0) as stocked_in_quantity
      FROM products p
      LEFT JOIN stock_balances sb ON p.id = sb.product_id AND sb.outlet_id = ?
      WHERE p.outlet_id = ? OR sb.outlet_id = ?
      GROUP BY p.id, p.product_name
    ''', [outletId, outletId, outletId]);

    Map<String, double> quantities = {};
    for (var row in result) {
      quantities[row['product_id'] as String] =
          (row['stocked_in_quantity'] as num).toDouble();
    }

    return quantities;
  }

  // Get sold quantities for products in an outlet
  Future<Map<String, double>> getSoldQuantities(String outletId) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT 
        p.id as product_id,
        p.product_name,
        COALESCE(sb.sold_quantity, 0) as sold_quantity
      FROM products p
      LEFT JOIN stock_balances sb ON p.id = sb.product_id AND sb.outlet_id = ?
      WHERE p.outlet_id = ? OR sb.outlet_id = ?
      GROUP BY p.id, p.product_name
    ''', [outletId, outletId, outletId]);

    Map<String, double> quantities = {};
    for (var row in result) {
      quantities[row['product_id'] as String] =
          (row['sold_quantity'] as num).toDouble();
    }

    return quantities;
  }

  // Initialize stock count items with theoretical quantities
  Future<List<StockCountItem>> initializeStockCountItems(
      String stockCountId, String outletId) async {
    final db = await _databaseHelper.database;
    final theoreticalQuantities = await getTheoreticalQuantities(outletId);

    // Get products for the outlet
    final products = await db.rawQuery('''
      SELECT DISTINCT p.id, p.product_name, p.cost_per_unit
      FROM products p
      LEFT JOIN stock_balances sb ON p.id = sb.product_id
      WHERE p.outlet_id = ? OR sb.outlet_id = ?
    ''', [outletId, outletId]);

    List<StockCountItem> items = [];

    for (var productData in products) {
      final productId = productData['id'] as String;
      final theoreticalQty = theoreticalQuantities[productId] ?? 0.0;

      final item = StockCountItem(
        id: _uuid.v4(),
        stockCountId: stockCountId,
        productId: productId,
        productName: productData['product_name'] as String,
        theoreticalQuantity: theoreticalQty,
        actualQuantity: 0.0, // To be filled during count
        costPerUnit: (productData['cost_per_unit'] as num).toDouble(),
        createdAt: DateTime.now(),
      );

      await db.insert('stock_count_items', item.toMap());
      items.add(item);
    }

    return items;
  }

  // Update actual quantity for a stock count item
  Future<StockCountItem> updateActualQuantity(
      String itemId, double actualQuantity,
      {String? notes}) async {
    final db = await _databaseHelper.database;

    // Get the current item
    final result = await db
        .query('stock_count_items', where: 'id = ?', whereArgs: [itemId]);
    if (result.isEmpty) throw Exception('Stock count item not found');

    final currentItem = StockCountItem.fromMap(result.first);

    // Create updated item with new actual quantity
    final updatedItem = StockCountItem(
      id: currentItem.id,
      stockCountId: currentItem.stockCountId,
      productId: currentItem.productId,
      productName: currentItem.productName,
      theoreticalQuantity: currentItem.theoreticalQuantity,
      actualQuantity: actualQuantity,
      costPerUnit: currentItem.costPerUnit,
      notes: notes ?? currentItem.notes,
      createdAt: currentItem.createdAt,
    );

    await db.update('stock_count_items', updatedItem.toMap(),
        where: 'id = ?', whereArgs: [itemId]);
    return updatedItem;
  }

  // Complete a stock count session
  Future<StockCount> completeStockCount(String stockCountId,
      {String? notes}) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();

    final updateData = {
      'status': 'completed',
      'completed_at': now.toIso8601String(),
      'notes': notes,
    };

    await db.update('stock_counts', updateData,
        where: 'id = ?', whereArgs: [stockCountId]);

    // Get updated stock count
    final result = await db
        .query('stock_counts', where: 'id = ?', whereArgs: [stockCountId]);
    return StockCount.fromMap(result.first);
  }

  // Get stock count items with variance
  Future<List<StockCountItem>> getStockCountItems(String stockCountId,
      {bool onlyWithVariance = false}) async {
    final db = await _databaseHelper.database;

    String whereClause = 'stock_count_id = ?';
    List<dynamic> whereArgs = [stockCountId];

    if (onlyWithVariance) {
      whereClause += ' AND ABS(variance) > 0.01';
    }

    final result = await db.query(
      'stock_count_items',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'ABS(variance) DESC, product_name ASC',
    );

    return result.map((map) => StockCountItem.fromMap(map)).toList();
  }

  // Create stock adjustments from count variances
  Future<List<StockAdjustment>> createAdjustmentsFromCount(
    String stockCountId,
    String createdBy, {
    double significanceThreshold = 0.01,
  }) async {
    final db = await _databaseHelper.database;

    // Get stock count and items with significant variance
    final stockCountResult = await db
        .query('stock_counts', where: 'id = ?', whereArgs: [stockCountId]);
    if (stockCountResult.isEmpty) throw Exception('Stock count not found');

    final stockCount = StockCount.fromMap(stockCountResult.first);

    // Get outlet info
    final outletResult = await db
        .query('outlets', where: 'id = ?', whereArgs: [stockCount.outletId]);
    final outletName = outletResult.isNotEmpty
        ? outletResult.first['name'] as String
        : 'Unknown Outlet';

    final items =
        await getStockCountItems(stockCountId, onlyWithVariance: true);

    List<StockAdjustment> adjustments = [];

    for (var item in items) {
      if (item.variance.abs() > significanceThreshold) {
        final adjustment = StockAdjustment(
          id: _uuid.v4(),
          productId: item.productId,
          outletId: stockCount.outletId,
          productName: item.productName,
          outletName: outletName,
          adjustmentQuantity: item.variance.abs(),
          adjustmentType: item.variance > 0 ? 'increase' : 'decrease',
          reason: item.adjustmentReason ?? 'counting_error',
          costPerUnit: item.costPerUnit,
          createdBy: createdBy,
          stockCountId: stockCountId,
          createdAt: DateTime.now(),
        );

        await db.insert('stock_adjustments', adjustment.toMap());
        adjustments.add(adjustment);
      }
    }

    return adjustments;
  }

  // Apply approved adjustments to stock balances
  Future<void> applyAdjustmentsToStock(List<String> adjustmentIds) async {
    final db = await _databaseHelper.database;

    await db.transaction((txn) async {
      for (String adjustmentId in adjustmentIds) {
        final adjustmentResult = await txn.query('stock_adjustments',
            where: 'id = ?', whereArgs: [adjustmentId]);
        if (adjustmentResult.isEmpty) continue;

        final adjustment = StockAdjustment.fromMap(adjustmentResult.first);
        if (adjustment.status != 'approved') continue;

        // Update stock balance
        final balanceResult = await txn.query(
          'stock_balances',
          where: 'product_id = ? AND outlet_id = ?',
          whereArgs: [adjustment.productId, adjustment.outletId],
        );

        if (balanceResult.isNotEmpty) {
          final currentBalance = StockBalance.fromMap(balanceResult.first);
          double newBalance;

          if (adjustment.adjustmentType == 'increase') {
            newBalance =
                currentBalance.balanceQuantity + adjustment.adjustmentQuantity;
          } else {
            newBalance =
                currentBalance.balanceQuantity - adjustment.adjustmentQuantity;
          }

          await txn.update(
            'stock_balances',
            {
              'balance_quantity': newBalance,
              'last_updated': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [currentBalance.id],
          );
        }
      }
    });
  }

  // Get stock count history
  Future<List<StockCount>> getStockCountHistory({
    String? outletId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int limit = 50,
  }) async {
    final db = await _databaseHelper.database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (outletId != null) {
      whereClause += ' AND outlet_id = ?';
      whereArgs.add(outletId);
    }

    if (startDate != null) {
      whereClause += ' AND count_date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND count_date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    final result = await db.query(
      'stock_counts',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'count_date DESC',
      limit: limit,
    );

    return result.map((map) => StockCount.fromMap(map)).toList();
  }

  // Get variance analysis report
  Future<Map<String, dynamic>> getVarianceAnalysisReport({
    String? outletId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _databaseHelper.database;

    String whereClause = 'sc.status = "completed"';
    List<dynamic> whereArgs = [];

    if (outletId != null) {
      whereClause += ' AND sc.outlet_id = ?';
      whereArgs.add(outletId);
    }

    if (startDate != null) {
      whereClause += ' AND sc.count_date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND sc.count_date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT sc.id) as total_counts,
        COUNT(sci.id) as total_items_counted,
        COUNT(CASE WHEN ABS(sci.variance) > 0.01 THEN 1 END) as items_with_variance,
        SUM(CASE WHEN sci.variance > 0 THEN sci.variance ELSE 0 END) as total_overage,
        SUM(CASE WHEN sci.variance < 0 THEN ABS(sci.variance) ELSE 0 END) as total_shortage,
        SUM(sci.value_impact) as total_value_impact,
        AVG(ABS(sci.variance_percentage)) as avg_variance_percentage
      FROM stock_counts sc
      LEFT JOIN stock_count_items sci ON sc.id = sci.stock_count_id
      WHERE $whereClause
    ''', whereArgs);

    if (result.isEmpty) {
      return {
        'total_counts': 0,
        'total_items_counted': 0,
        'items_with_variance': 0,
        'total_overage': 0.0,
        'total_shortage': 0.0,
        'total_value_impact': 0.0,
        'avg_variance_percentage': 0.0,
        'accuracy_percentage': 100.0,
      };
    }

    final data = result.first;
    final totalItems = (data['total_items_counted'] as num?)?.toInt() ?? 0;
    final itemsWithVariance =
        (data['items_with_variance'] as num?)?.toInt() ?? 0;
    final accuracyPercentage = totalItems > 0
        ? ((totalItems - itemsWithVariance) / totalItems) * 100
        : 100.0;

    return {
      'total_counts': (data['total_counts'] as num?)?.toInt() ?? 0,
      'total_items_counted': totalItems,
      'items_with_variance': itemsWithVariance,
      'total_overage': (data['total_overage'] as num?)?.toDouble() ?? 0.0,
      'total_shortage': (data['total_shortage'] as num?)?.toDouble() ?? 0.0,
      'total_value_impact':
          (data['total_value_impact'] as num?)?.toDouble() ?? 0.0,
      'avg_variance_percentage':
          (data['avg_variance_percentage'] as num?)?.toDouble() ?? 0.0,
      'accuracy_percentage': accuracyPercentage,
    };
  }

  // Delete a stock count (only if in progress)
  Future<bool> deleteStockCount(String stockCountId) async {
    final db = await _databaseHelper.database;

    // Check if stock count is in progress
    final result = await db.query('stock_counts',
        where: 'id = ? AND status = ?',
        whereArgs: [stockCountId, 'in_progress']);
    if (result.isEmpty) return false;

    await db.transaction((txn) async {
      // Delete stock count items first
      await txn.delete('stock_count_items',
          where: 'stock_count_id = ?', whereArgs: [stockCountId]);
      // Delete stock count
      await txn
          .delete('stock_counts', where: 'id = ?', whereArgs: [stockCountId]);
    });

    return true;
  }
}
