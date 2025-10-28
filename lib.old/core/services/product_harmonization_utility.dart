import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/product_model.dart';

class ProductHarmonizationUtility {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// Get a report of duplicate products without fixing them
  Future<List<Map<String, dynamic>>> getDuplicateProductsReport() async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT 
        product_name,
        outlet_id,
        COUNT(*) as count,
        GROUP_CONCAT(id) as product_ids
      FROM products 
      GROUP BY LOWER(TRIM(product_name)), outlet_id 
      HAVING COUNT(*) > 1
      ORDER BY count DESC, product_name
    ''');

    return result;
  }

  /// Harmonize existing duplicate products by merging them
  Future<Map<String, int>> harmonizeExistingDuplicates() async {
    final db = await _databaseHelper.database;
    int mergedProducts = 0;
    int updatedReferences = 0;

    return await db.transaction((txn) async {
      // Get all duplicate groups
      final duplicateGroups = await txn.rawQuery('''
        SELECT 
          product_name,
          outlet_id,
          COUNT(*) as count,
          GROUP_CONCAT(id) as product_ids
        FROM products 
        GROUP BY LOWER(TRIM(product_name)), outlet_id 
        HAVING COUNT(*) > 1
      ''');

      for (final group in duplicateGroups) {
        final productIds = (group['product_ids'] as String).split(',');
        if (productIds.length <= 1) continue;

        // Get all products in this duplicate group
        final products = await txn.query(
          'products',
          where: 'id IN (${productIds.map((_) => '?').join(',')})',
          whereArgs: productIds,
          orderBy: 'date_added ASC', // Keep the oldest one as primary
        );

        if (products.isEmpty) continue;

        final primaryProduct = Product.fromMap(products.first);
        final duplicateProductIds = productIds.skip(1).toList();

        // Calculate merged quantities and average cost
        double totalQuantity = 0;
        double totalCost = 0;
        DateTime? latestDate;

        for (final productMap in products) {
          final product = Product.fromMap(productMap);
          totalQuantity += product.quantity;
          totalCost += product.quantity * product.costPerUnit;

          if (latestDate == null || product.dateAdded.isAfter(latestDate)) {
            latestDate = product.dateAdded;
          }
        }

        final averageCostPerUnit =
            totalQuantity > 0 ? totalCost / totalQuantity : 0.0;

        // Update the primary product with merged data
        await txn.update(
          'products',
          {
            'quantity': totalQuantity,
            'cost_per_unit': averageCostPerUnit,
            'date_added': latestDate?.toIso8601String() ??
                primaryProduct.dateAdded.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [primaryProduct.id],
        );

        // Update references in sale_items table
        for (final duplicateId in duplicateProductIds) {
          final saleItemsUpdated = await txn.update(
            'sale_items',
            {'product_id': primaryProduct.id},
            where: 'product_id = ?',
            whereArgs: [duplicateId],
          );
          updatedReferences += saleItemsUpdated;
        }

        // Update references in stock_balances table
        for (final duplicateId in duplicateProductIds) {
          final stockBalancesUpdated = await txn.update(
            'stock_balances',
            {'product_id': primaryProduct.id},
            where: 'product_id = ?',
            whereArgs: [duplicateId],
          );
          updatedReferences += stockBalancesUpdated;
        }

        // Update references in product_distributions table
        for (final duplicateId in duplicateProductIds) {
          final distributionsUpdated = await txn.update(
            'product_distributions',
            {'product_id': primaryProduct.id},
            where: 'product_id = ?',
            whereArgs: [duplicateId],
          );
          updatedReferences += distributionsUpdated;
        }

        // Delete duplicate products
        await txn.delete(
          'products',
          where: 'id IN (${duplicateProductIds.map((_) => '?').join(',')})',
          whereArgs: duplicateProductIds,
        );

        mergedProducts += duplicateProductIds.length;
      }

      return {
        'mergedProducts': mergedProducts,
        'updatedReferences': updatedReferences,
      };
    });
  }

  /// Check if a product with the same name and outlet already exists
  Future<Product?> findExistingProduct(
      String productName, String outletId) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'products',
      where: 'LOWER(TRIM(product_name)) = LOWER(TRIM(?)) AND outlet_id = ?',
      whereArgs: [productName, outletId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return Product.fromMap(result.first);
    }

    return null;
  }

  /// Merge a new product into an existing one
  Future<void> mergeIntoExistingProduct(
    Product existingProduct,
    double newQuantity,
    double newCostPerUnit,
  ) async {
    final db = await _databaseHelper.database;

    // Calculate new totals
    final existingTotalCost =
        existingProduct.quantity * existingProduct.costPerUnit;
    final newTotalCost = newQuantity * newCostPerUnit;
    final combinedQuantity = existingProduct.quantity + newQuantity;
    final averageCostPerUnit = combinedQuantity > 0
        ? (existingTotalCost + newTotalCost) / combinedQuantity
        : 0.0;

    // Update the existing product
    await db.update(
      'products',
      {
        'quantity': combinedQuantity,
        'cost_per_unit': averageCostPerUnit,
        'date_added':
            DateTime.now().toIso8601String(), // Update to current time
      },
      where: 'id = ?',
      whereArgs: [existingProduct.id],
    );
  }
}
