import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

void main() async {
  // Initialize FFI
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Get database path
  final appDataPath = Platform.environment['APPDATA'] ?? 'C:\\Users\\HP\\AppData\\Roaming';
  final dbPath = '$appDataPath\\hadraniel_admin\\hadraniel_admin.db';

  print('Opening database at: $dbPath');
  final db = await openDatabase(dbPath, readOnly: true);

  // Check for sales without sale_items
  print('\n===== SALES WITHOUT ITEMS =====');
  final salesWithoutItems = await db.rawQuery('''
    SELECT s.id, s.created_at, s.outlet_id, s.total_amount,
           COUNT(si.id) as item_count
    FROM sales s
    LEFT JOIN sale_items si ON si.sale_id = s.id
    GROUP BY s.id
    HAVING COUNT(si.id) = 0
    ORDER BY s.created_at DESC
    LIMIT 20
  ''');

  print('Found ${salesWithoutItems.length} sales without any items');
  for (var sale in salesWithoutItems) {
    print('  Sale ${sale['id']}: Date=${sale['created_at']}, Amount=${sale['total_amount']}');
  }

  // Check total counts
  print('\n===== TOTAL COUNTS =====');
  final totalSales = await db.rawQuery('SELECT COUNT(*) as count FROM sales');
  final totalItems = await db.rawQuery('SELECT COUNT(*) as count FROM sale_items');
  print('Total sales: ${totalSales.first['count']}');
  print('Total sale_items: ${totalItems.first['count']}');

  // Check for sale_items with NULL product_name
  print('\n===== ITEMS WITH NULL PRODUCT_NAME =====');
  final nullNameItems = await db.rawQuery('''
    SELECT si.id, si.sale_id, si.product_id, si.product_name
    FROM sale_items si
    WHERE si.product_name IS NULL OR si.product_name = ''
    LIMIT 20
  ''');

  print('Found ${nullNameItems.length} items with NULL/empty product_name');
  for (var item in nullNameItems) {
    print('  Item ${item['id']}: Sale=${item['sale_id']}, Product=${item['product_id']}, Name=${item['product_name']}');
  }

  await db.close();
  print('\nDone!');
}
