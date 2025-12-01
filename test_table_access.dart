import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> _loadEnvWithFallback() async {
  try {
    await dotenv.load(fileName: '.env');
    print('✅ Loaded env from .env');
    return;
  } catch (_) {}

  try {
    await dotenv.load(fileName: 'lib/env/.env');
    print('✅ Loaded env from lib/env/.env');
    return;
  } catch (e) {
    print('❌ Failed to load env file: $e');
    rethrow;
  }
}

Future<void> main() async {
  try {
    // Load environment variables with fallback
    await _loadEnvWithFallback();

    // Initialize Supabase
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    final supabase = Supabase.instance.client;

    print('🔍 Testing table access permissions...\n');

    // Test 1: Products table access
    print('1. Testing products table access:');
    try {
      final productsResponse = await supabase
          .from('products')
          .select('id, product_name, outlet_id')
          .limit(5);
      print(
          '   ✅ Products table accessible - Found ${productsResponse.length} records');
      if (productsResponse.isNotEmpty) {
        print('   📋 Sample product: ${productsResponse.first}');
      }
    } catch (e) {
      print('   ❌ Products table access failed: $e');
    }

    print('');

    // Test 2: Stock balances table access
    print('2. Testing stock_balances table access:');
    try {
      final stockResponse = await supabase
          .from('stock_balances')
          .select('id, outlet_id, product_id, given_quantity, balance_quantity')
          .limit(5);
      print(
          '   ✅ Stock balances table accessible - Found ${stockResponse.length} records');
      if (stockResponse.isNotEmpty) {
        print('   📋 Sample stock balance: ${stockResponse.first}');
      }
    } catch (e) {
      print('   ❌ Stock balances table access failed: $e');
    }

    print('');

    // Test 3: Sale items table access
    print('3. Testing sale_items table access:');
    try {
      final saleItemsResponse = await supabase
          .from('sale_items')
          .select('id, sale_id, product_id, quantity, unit_price')
          .limit(5);
      print(
          '   ✅ Sale items table accessible - Found ${saleItemsResponse.length} records');
      if (saleItemsResponse.isNotEmpty) {
        print('   📋 Sample sale item: ${saleItemsResponse.first}');
      }
    } catch (e) {
      print('   ❌ Sale items table access failed: $e');
    }

    print('');

    // Test 4: Check if user is authenticated
    print('4. Testing authentication status:');
    final user = supabase.auth.currentUser;
    if (user != null) {
      print('   ✅ User authenticated: ${user.email}');

      // Try to get user profile
      try {
        final profileResponse = await supabase
            .from('profiles')
            .select('id, full_name, role, outlet_id')
            .eq('id', user.id)
            .single();
        print('   👤 User profile: ${profileResponse}');
      } catch (e) {
        print('   ❌ Failed to get user profile: $e');
      }
    } else {
      print('   ⚠️  No authenticated user - using anonymous access');
    }

    print('\n🏁 Table access test completed!');
  } catch (e) {
    print('❌ Test failed with error: $e');
  }
}