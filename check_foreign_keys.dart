import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() async {
  // Initialize FFI
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Get the database path
  final dbPath = join(
      Platform.environment['LOCALAPPDATA']!, 'Hadraniel_Admin', 'admin_app.db');
  print('Database path: $dbPath');

  // Open database
  final db = await openDatabase(dbPath);

  // Check the problematic outlet_id and product_id from the error
  final outletId = 'fc553f2d-1a1f-4f90-ac4a-6f152e829ab8';
  final productId = 'c3b2b3ef-2eb6-46f9-93e1-aaf10198b00b';

  print('\nChecking foreign key references...');

  // Check if outlet exists
  final outletResult =
      await db.query('outlets', where: 'id = ?', whereArgs: [outletId]);
  print('Outlet $outletId exists: ${outletResult.isNotEmpty}');
  if (outletResult.isNotEmpty) {
    print('Outlet details: ${outletResult.first}');
  }

  // Check if product exists
  final productResult =
      await db.query('products', where: 'id = ?', whereArgs: [productId]);
  print('Product $productId exists: ${productResult.isNotEmpty}');
  if (productResult.isNotEmpty) {
    print('Product details: ${productResult.first}');
  }

  // Count total outlets and products
  final outletCountResult =
      await db.rawQuery('SELECT COUNT(*) as count FROM outlets');
  final outletCount = outletCountResult.first['count'] as int;

  final productCountResult =
      await db.rawQuery('SELECT COUNT(*) as count FROM products');
  final productCount = productCountResult.first['count'] as int;

  final stockBalanceCountResult =
      await db.rawQuery('SELECT COUNT(*) as count FROM stock_balances');
  final stockBalanceCount = stockBalanceCountResult.first['count'] as int;

  print('\nDatabase summary:');
  print('Total outlets: $outletCount');
  print('Total products: $productCount');
  print('Total stock_balances: $stockBalanceCount');

  // Check for orphaned stock_balances
  final orphanedOutlets = await db.rawQuery('''
    SELECT DISTINCT sb.outlet_id 
    FROM stock_balances sb 
    LEFT JOIN outlets o ON sb.outlet_id = o.id 
    WHERE o.id IS NULL
  ''');

  final orphanedProducts = await db.rawQuery('''
    SELECT DISTINCT sb.product_id 
    FROM stock_balances sb 
    LEFT JOIN products p ON sb.product_id = p.id 
    WHERE p.id IS NULL
  ''');

  print('\nOrphaned references:');
  print('Stock balances with missing outlets: ${orphanedOutlets.length}');
  if (orphanedOutlets.isNotEmpty) {
    print(
        'Missing outlet IDs: ${orphanedOutlets.map((e) => e['outlet_id']).toList()}');
  }

  print('Stock balances with missing products: ${orphanedProducts.length}');
  if (orphanedProducts.isNotEmpty) {
    print(
        'Missing product IDs: ${orphanedProducts.map((e) => e['product_id']).toList()}');
  }

  await db.close();
}
