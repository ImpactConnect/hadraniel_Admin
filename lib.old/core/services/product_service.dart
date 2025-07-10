import 'package:hadraniel_admin/core/database/database_helper.dart';
import 'package:hadraniel_admin/core/models/product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ProductService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Local DB Operations
  Future<void> insertProduct(Product product) async {
    final db = await _dbHelper.database;
    await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Product>> getAllProducts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<Product?> getProductById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<List<Product>> getProductsByOutlet(String outletId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'outlet_id = ?',
      whereArgs: [outletId],
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<void> updateProduct(Product product) async {
    final db = await _dbHelper.database;
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(String id) async {
    final db = await _dbHelper.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // Supabase Operations
  Future<void> syncProductsToSupabase() async {
    try {
      final products = await getAllProducts();
      for (var product in products) {
        await _supabase.from('products').upsert(product.toJson());
      }
    } catch (e) {
      throw Exception('Failed to sync products to Supabase: $e');
    }
  }

  Future<void> fetchProductsFromSupabase() async {
    try {
      final response = await _supabase.from('products').select();
      if (response is! List) {
        throw Exception('Invalid response format from Supabase');
      }

      for (var productData in response) {
        if (productData is! Map<String, dynamic>) {
          continue; // Skip invalid data
        }
        try {
          final product = Product.fromJson(productData);
          await insertProduct(product);
        } catch (e) {
          print('Error processing product data: $e');
          continue; // Skip problematic records
        }
      }
    } catch (e) {
      throw Exception('Failed to fetch products from Supabase: $e');
    }
  }
}
