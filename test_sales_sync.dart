import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() async {
  // Initialize SQLite for Windows
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase client
  final supabase = SupabaseClient(
    dotenv.env['SUPABASE_URL'] ?? '',
    dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  print('Testing sales synchronization...');
  
  try {
    // Test connection to sales table
    print('\nTesting connection to sales table...');
    final salesResponse = await supabase.from('sales').select().limit(5);
    print('Sales in cloud database: ${salesResponse.length}');
    
    // Test connection to sale_items table
    print('\nTesting connection to sale_items table...');
    final saleItemsResponse = await supabase.from('sale_items').select().limit(5);
    print('Sale items in cloud database: ${saleItemsResponse.length}');
    
    // Open local database
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'hadraniel_admin.db');
    print('\nDatabase path: $path');
    
    final db = await openDatabase(path);
    
    // Check if tables exist and have is_synced column
    print('\nChecking database schema...');
    final salesTableInfo = await db.rawQuery('PRAGMA table_info(sales)');
    print('Sales table columns:');
    for (var column in salesTableInfo) {
      print('  ${column['name']}: ${column['type']}');
    }
    
    final saleItemsTableInfo = await db.rawQuery('PRAGMA table_info(sale_items)');
    print('\nSale items table columns:');
    for (var column in saleItemsTableInfo) {
      print('  ${column['name']}: ${column['type']}');
    }
    
    // Check local database content
    print('\nChecking local database content...');
    final localSalesCount = await db.rawQuery('SELECT COUNT(*) as count FROM sales');
    final localSaleItemsCount = await db.rawQuery('SELECT COUNT(*) as count FROM sale_items');
    print('Local sales count: ${localSalesCount[0]['count']}');
    print('Local sale items count: ${localSaleItemsCount[0]['count']}');
    
    // Check for unsynced records
    final unsyncedSales = await db.rawQuery('SELECT COUNT(*) as count FROM sales WHERE is_synced = 0');
    final unsyncedSaleItems = await db.rawQuery('SELECT COUNT(*) as count FROM sale_items WHERE is_synced = 0');
    print('Unsynced sales: ${unsyncedSales[0]['count']}');
    print('Unsynced sale items: ${unsyncedSaleItems[0]['count']}');
    
    // Sample some sales data
    final sampleSales = await db.rawQuery('SELECT * FROM sales LIMIT 3');
    print('\nSample sales data:');
    for (var sale in sampleSales) {
      print('  Sale ID: ${sale['id']}, Total: ${sale['total_amount']}, Synced: ${sale['is_synced']}');
    }
    
    await db.close();
    
    print('\nDatabase test completed successfully!');
    
  } catch (e, stackTrace) {
    print('Error during database test: $e');
    print('Stack trace: $stackTrace');
  }
  
  exit(0);
}