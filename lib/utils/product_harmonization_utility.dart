import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/models/product_model.dart';
import '../core/services/sync_service.dart';

class ProductHarmonizationUtility {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _syncService = SyncService();

  /// Clean up existing duplicate products in the database
  /// This method finds products with the same name and outlet, then merges them
  Future<Map<String, dynamic>> harmonizeExistingDuplicates() async {
    try {
      final db = await _dbHelper.database;
      int duplicatesFound = 0;
      int duplicatesResolved = 0;
      List<String> processedProducts = [];

      // Find all duplicate products grouped by product_name and outlet_id
      final List<Map<String, dynamic>> duplicateGroups = await db.rawQuery('''
        SELECT product_name, outlet_id, COUNT(*) as duplicate_count
        FROM products
        GROUP BY product_name, outlet_id
        HAVING COUNT(*) > 1
        ORDER BY product_name, outlet_id
      ''');

      duplicatesFound = duplicateGroups.length;

      for (final group in duplicateGroups) {
        final productName = group['product_name'] as String;
        final outletId = group['outlet_id'] as String;
        final duplicateCount = group['duplicate_count'] as int;

        // Get all duplicate products for this group
        final List<Map<String, dynamic>> duplicateProducts = await db.query(
          'products',
          where: 'product_name = ? AND outlet_id = ?',
          whereArgs: [productName, outletId],
          orderBy: 'date_added ASC', // Keep the oldest one as the primary
        );

        if (duplicateProducts.length > 1) {
          await _mergeDuplicateProducts(duplicateProducts);
          duplicatesResolved++;
          processedProducts.add(
              '$productName (${await _syncService.getOutletName(outletId)})');
        }
      }

      return {
        'success': true,
        'duplicatesFound': duplicatesFound,
        'duplicatesResolved': duplicatesResolved,
        'processedProducts': processedProducts,
        'message': duplicatesResolved > 0
            ? 'Successfully harmonized $duplicatesResolved duplicate product groups.'
            : 'No duplicate products found to harmonize.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error occurred while harmonizing duplicates: $e',
      };
    }
  }

  /// Merge multiple duplicate products into one
  Future<void> _mergeDuplicateProducts(
      List<Map<String, dynamic>> duplicateProducts) async {
    if (duplicateProducts.length <= 1) return;

    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // Use the first (oldest) product as the primary one
      final primaryProductMap = duplicateProducts.first;
      final primaryProduct = Product.fromMap(primaryProductMap);

      // Calculate merged values from all duplicates
      double totalQuantity = 0;
      double totalCost = 0;
      String? mergedDescription;
      DateTime? latestUpdate;

      for (final productMap in duplicateProducts) {
        final product = Product.fromMap(productMap);
        totalQuantity += product.quantity;
        totalCost += product.totalCost;

        // Merge descriptions
        if (product.description != null && product.description!.isNotEmpty) {
          if (mergedDescription == null || mergedDescription.isEmpty) {
            mergedDescription = product.description;
          } else if (!mergedDescription.contains(product.description!)) {
            mergedDescription += '; ${product.description}';
          }
        }

        // Track latest update
        if (product.lastUpdated != null) {
          if (latestUpdate == null ||
              product.lastUpdated!.isAfter(latestUpdate)) {
            latestUpdate = product.lastUpdated;
          }
        }
      }

      // Calculate average cost per unit
      final averageCostPerUnit =
          totalQuantity > 0 ? totalCost / totalQuantity : 0.0;

      // Update the primary product with merged data
      final mergedProduct = Product(
        id: primaryProduct.id,
        productName: primaryProduct.productName,
        quantity: totalQuantity,
        unit: primaryProduct.unit,
        costPerUnit: averageCostPerUnit,
        totalCost: totalCost,
        dateAdded: primaryProduct.dateAdded, // Keep original date
        lastUpdated: latestUpdate ?? DateTime.now(),
        description: mergedDescription ?? primaryProduct.description,
        outletId: primaryProduct.outletId,
        createdAt: primaryProduct.createdAt,
        isSynced: false, // Mark for sync
      );

      // Update the primary product
      await txn.update(
        'products',
        mergedProduct.toMap(),
        where: 'id = ?',
        whereArgs: [primaryProduct.id],
      );

      // Update any references to the duplicate products in other tables
      for (int i = 1; i < duplicateProducts.length; i++) {
        final duplicateId = duplicateProducts[i]['id'] as String;

        // Update sale_items references
        await txn.update(
          'sale_items',
          {'product_id': primaryProduct.id},
          where: 'product_id = ?',
          whereArgs: [duplicateId],
        );

        // Update stock_balances references
        await txn.update(
          'stock_balances',
          {'product_id': primaryProduct.id},
          where: 'product_id = ?',
          whereArgs: [duplicateId],
        );

        // Delete the duplicate product
        await txn.delete(
          'products',
          where: 'id = ?',
          whereArgs: [duplicateId],
        );
      }
    });
  }

  /// Get a report of current duplicate products without fixing them
  Future<Map<String, dynamic>> getDuplicateProductsReport() async {
    try {
      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> duplicateGroups = await db.rawQuery('''
        SELECT 
          product_name, 
          outlet_id,
          COUNT(*) as duplicate_count,
          SUM(quantity) as total_quantity,
          SUM(total_cost) as total_cost
        FROM products
        GROUP BY product_name, outlet_id
        HAVING COUNT(*) > 1
        ORDER BY duplicate_count DESC, product_name
      ''');

      List<Map<String, dynamic>> detailedReport = [];

      for (final group in duplicateGroups) {
        final productName = group['product_name'] as String;
        final outletId = group['outlet_id'] as String;
        final outletName =
            await _syncService.getOutletName(outletId) ?? 'Unknown';

        detailedReport.add({
          'productName': productName,
          'outletName': outletName,
          'duplicateCount': group['duplicate_count'],
          'totalQuantity': group['total_quantity'],
          'totalCost': group['total_cost'],
        });
      }

      return {
        'success': true,
        'totalDuplicateGroups': duplicateGroups.length,
        'duplicateGroups': detailedReport,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
