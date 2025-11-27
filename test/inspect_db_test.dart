import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

void main() {
  test('Inspect Database', () async {
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    String dbPath;
    if (Platform.isWindows) {
      final appDataPath = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          Directory.current.path;
      dbPath = join(appDataPath, 'Hadraniel_Admin', 'admin_app.db');
    } else {
      dbPath = join(Directory.current.path, 'hadraniel_admin.db');
    }
    print('Opening database at: $dbPath');

    final db = await databaseFactory.openDatabase(dbPath);

    try {
      // 1. Count total sales and sale items
      final salesCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sales'));
      final itemsCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sale_items'));
      
      print('Total Sales: $salesCount');
      print('Total Sale Items: $itemsCount');

      // 2. Find sales with NO items (orphaned sales)
      final orphanedSales = await db.rawQuery('''
        SELECT s.id, s.created_at, s.total_amount 
        FROM sales s
        LEFT JOIN sale_items si ON s.id = si.sale_id
        WHERE si.id IS NULL
        LIMIT 10
      ''');

      print('\n--- Sales with NO Items (Top 10) ---');
      if (orphanedSales.isEmpty) {
        print('None found! All sales have items.');
      } else {
        for (var sale in orphanedSales) {
          print('Sale ID: ${sale['id']}, Date: ${sale['created_at']}, Amount: ${sale['total_amount']}');
        }
      }

      // 3. Check if there are any sale_items that point to non-existent sales (just in case)
      final orphanedItems = await db.rawQuery('''
        SELECT si.id, si.sale_id, si.product_id
        FROM sale_items si
        LEFT JOIN sales s ON si.sale_id = s.id
        WHERE s.id IS NULL
        LIMIT 10
      ''');
      
      print('\n--- Sale Items with NO Parent Sale (Top 10) ---');
      if (orphanedItems.isEmpty) {
        print('None found.');
      } else {
        for (var item in orphanedItems) {
          print('Item ID: ${item['id']}, Sale ID: ${item['sale_id']}');
        }
      }

      // 4. Count total sale items (redundant but explicit)
      final saleItemsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM sale_items'),
      );
      print('Total Sale Items (Check 2): $saleItemsCount');

      // 5. Check for specific missing product from logs
      final missingProductId = '4b443cdc-72be-45a4-9295-e582377bd213';
      final productCheck = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [missingProductId],
      );
      
      if (productCheck.isEmpty) {
        print('CRITICAL: Product $missingProductId is MISSING from local DB!');
      } else {
        print('Product $missingProductId exists in local DB.');
      }

      // 6. Check for any products
      final productsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM products'),
      );
      print('Total Products: $productsCount');

    } catch (e) {
      print('Error: $e');
    } finally {
      await db.close();
    }
  });
}
